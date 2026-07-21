# Navigation 고급 패턴

여러 navigation 패턴, deep linking, 재귀적 navigation입니다.

## 여러 Navigation 패턴

### NavigationStack + Sheet

```swift
@Reducer
struct Feature {
    @Reducer
    enum Path {
        case detail(Detail)
        case settings(Settings)
    }

    @Reducer
    enum Destination {
        case alert(AlertState<Alert>)
        case sheet(Sheet)
    }

    @ObservableState
    struct State: Equatable {
        var path = StackState<Path.State>()
        @Presents var destination: Destination.State?
    }

    enum Action {
        case path(StackActionOf<Path>)
        case destination(PresentationAction<Destination.Action>)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            // Handle actions
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$destination, action: \.destination)
    }
}
```

View:

```swift
struct FeatureView: View {
    @Bindable var store: StoreOf<Feature>

    var body: some View {
        NavigationStack(
            path: $store.scope(state: \.path, action: \.path)
        ) {
            RootView()
        } destination: { store in
            switch store.case {
            case let .detail(store):
                DetailView(store: store)
            case let .settings(store):
                SettingsView(store: store)
            }
        }
        .sheet(
            item: $store.scope(state: \.destination?.sheet, action: \.destination.sheet)
        ) { store in
            SheetView(store: store)
        }
        .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    }
}
```

## Deep Linking

### 초기 Path 설정하기

```swift
// Set path on initialization or deep link
@ObservableState
struct State: Equatable {
    var path = StackState<Path.State>()

    init(deepLink: DeepLink? = nil) {
        if let deepLink {
            self.path = deepLink.navigationPath
        }
    }
}
```

### 외부 이벤트로부터 navigation하기

```swift
case .deepLinkReceived(let deepLink):
    state.path.removeAll()
    switch deepLink {
    case .detail(let id):
        state.path.append(.detail(Detail.State(id: id)))
    case .settings:
        state.path.append(.settings(Settings.State()))
    }
    return .none
```

## NavigationStack State 검사

### 현재 화면 확인하기

```swift
// Check if specific screen is in stack
let isDetailPresented = state.path.contains { $0.is(\.detail) }

// Get specific screen state
if case let .detail(detailState) = state.path.last {
    // Access detail state
}

// Count screens
let screenCount = state.path.count
```

## 재귀적 Navigation

자기 참조 navigation(예: 중첩된 폴더)의 경우:

```swift
@Reducer
struct Nested {
    @ObservableState
    struct State: Equatable, Identifiable {
        let id: UUID
        var name: String = ""
        var rows: IdentifiedArrayOf<State> = []
    }

    enum Action {
        case addRowButtonTapped
        indirect case rows(IdentifiedActionOf<Nested>)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .addRowButtonTapped:
                state.rows.append(State(id: UUID()))
                return .none

            case .rows:
                return .none
            }
        }
        .forEach(\.rows, action: \.rows) {
            Self()  // Recursive reference
        }
    }
}
```

View:

```swift
struct NestedView: View {
    let store: StoreOf<Nested>

    var body: some View {
        Form {
            TextField("Name", text: $store.name)

            Button("Add Row") {
                store.send(.addRowButtonTapped)
            }

            ForEach(
                store.scope(state: \.rows, action: \.rows)
            ) { childStore in
                NavigationLink(state: childStore) {
                    Text(childStore.name)
                }
            }
        }
    }
}
```

## Best Practices

1. **`@Presents` 사용** - navigation과 함께 sheet, alert, popover를 위해 사용
2. **Deep linking** - 외부 이벤트 발생 시 초기 path를 설정하거나 path를 조작
3. **State 검사** - navigation state를 확인하기 위해 `.contains`와 pattern matching을 사용
4. **재귀적 패턴** - tree 구조를 위해 `indirect case`와 `Self()`를 사용
5. **패턴 결합** - NavigationStack + sheet/alert destination은 함께 잘 동작함
