# Reducer 구조, Action, State

TCA reducer를 구조화하고, action을 정리하고, state를 정의하는 세부 패턴입니다.

## Reducer 구조

### 기본 Reducer 템플릿

```swift
@Reducer
public struct FeatureNameReducer {

    @ObservableState
    public struct State: Equatable {
        // State properties
        public init() {}
    }

    public enum Action: ViewAction {
        // Actions that are called from this reducer's view, and this reducer's view only.
        enum View {
            case onAppear
        }
        case view(View)
        // Actions that this reducer can use to delegate to other reducers.
        case delegate(Delegate)
        // Actions that can be triggered from other reducers.
        case interface(Interface)
        // Internal actions
    }

    public init() {}

    @Dependency(\.dependencyName) var dependencyName

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                switch viewAction {
                case .onAppear:
                    return .send(.loadData)
                case .didTapSave:
                    return .send(.saveData)
                }

            case .delegate:
                return .none

            case .interface:
                return .none
            }
        }
        .ifLet(\.childState, action: \.childAction) {
            ChildReducer()
        }
        .ifLet(\.$destination, action: \.destination)
    }
}
```

### @Reducer Enum 준수(Conformance)

**중요**: `@Reducer` enum 정의는 `Equatable`이나 `Sendable` 같은 protocol conformance에 반드시 extension을 사용해야 합니다. `@Reducer` 선언에 직접 conformance를 추가하지 마세요.

```swift
// ❌ INCORRECT - Do not add conformances directly
@Reducer enum Destination: Equatable {
    case settings(SettingsFeature)
}

// ✅ CORRECT - Use extension for conformances
@Reducer enum Destination {
    case settings(SettingsFeature)
}

extension Destination: Equatable {}
```

**패턴**: extension은 항상 file scope에서, 부모 reducer의 닫는 중괄호 바로 뒤에 정의하세요.

```swift
@Reducer
struct ParentFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
    }

    enum Action {
        case destination(PresentationAction<Destination.Action>)
    }

    @Reducer enum Destination {
        case settings(SettingsFeature)
        case detail(DetailFeature)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            // ...
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

// Extension must be at file scope, after the reducer definition
extension ParentFeature.Destination: Equatable {}
```

**이렇게 해야 하는 이유**: `@Reducer` macro는 enum 선언에 직접 추가된 conformance와 충돌하는 코드를 생성합니다. extension을 사용하면 macro가 생성한 코드가 올바르게 동작하면서도 필요한 protocol conformance를 제공할 수 있습니다.

## Action 정리

Action은 항상 의도된 용도에 따라 정리하세요.

```swift
public enum Action: ViewAction {
    // MARK: - View Actions
    enum View {
        case onAppear
        case didTapSave
        case didTapCancel
        case didSelectItem(Int)
        case didChangeText(String)
    }
    case view(View)

    // MARK: - Delegate Actions
    enum Delegate: Equatable {
        case userDidCompleteFlow
        case onDataLoaded(Data)
        case onError(Error)
    }
    case delegate(Delegate)

    // MARK: - Interface Actions
    enum Interface: Equatable {
        case refresh
        case reload
        case updateData(Data)
    }
    case interface(Interface)

    // MARK: - Internal Actions
    case loadData
    case didLoadData(Result<Data, Error>)
    case saveData
    case didSaveData(Result<Void, Error>)
    case setAlertState(AlertState<Action.Alert>)
    case setDestination(Destination.State?)

    // MARK: - Presentation Actions
    case destination(PresentationAction<Destination.Action>)
    case alert(PresentationAction<Action.Alert>)
}
```

## Action의 Result 타입

성공과 실패 케이스를 모두 처리하기 위해 비동기 작업 응답에 `Result` 타입을 사용하세요.

```swift
enum Action {
    case numberFactButtonTapped
    case numberFactResponse(Result<String, any Error>)
    case loadUserButtonTapped
    case userResponse(Result<User, any Error>)
}
```

Reducer에서 처리:

```swift
case .numberFactButtonTapped:
    state.isLoading = true
    return .run { [count = state.count] send in
        await send(.numberFactResponse(Result {
            try await factClient.fetch(count)
        }))
    }

case .numberFactResponse(.success(let fact)):
    state.isLoading = false
    state.fact = fact
    return .none

case .numberFactResponse(.failure(let error)):
    state.isLoading = false
    state.alert = AlertState {
        TextState("Error loading fact: \(error.localizedDescription)")
    }
    return .none
```

### catch를 사용한 Result:

또는 effect의 `catch:` 매개변수를 사용할 수도 있습니다.

```swift
case .loadItem(let id):
    return .run { send in
        let item = try await apiClient.fetchItem(id)
        await send(.itemLoaded(item))
    } catch: { error, send in
        await send(.loadFailed(error))
    }
```

## State 관리

### Observable State

```swift
@ObservableState
public struct State: Equatable {
    // Basic properties
    var isLoading: Bool = false
    var data: [Item] = []
    var selectedItem: Item?

    // Shared state
    @Shared var userPreferences: UserPreferences

    // Presentation state
    @Presents var destination: Destination.State?
    @Presents var alert: AlertState<Action.Alert>?

    // Computed properties
    var isEmpty: Bool {
        data.isEmpty
    }

    var canSave: Bool {
        !data.isEmpty && !isLoading
    }
}
```

### CasePathable을 사용한 복합 State

```swift
@ObservableState
public struct State: Equatable {
    @CasePathable
    @dynamicMemberLookup
    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded(Data)
        case error(Error)
    }

    var loadingState: LoadingState = .idle
    var otherProperties: String = ""
}
```
