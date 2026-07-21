# Presentation State

TCA(navigation destination, alert, sheet)에서 presentation state를 관리하기 위한 패턴입니다.

## Destination 관리

### 통합 Destination 패턴 (권장)

모든 presentation case(sheet, alert, navigation)를 관리하기 위해 **단일 `@Presents var destination: Destination.State?` property**를 사용하세요. 이 패턴은 더 나은 type safety, 더 깔끔한 state 관리, 더 단순한 reducer composition을 제공합니다.

**이점:**
- ✅ Type-safe: compiler가 모든 presentation case가 처리되는지 보장함
- ✅ 상호 배타적: 한 번에 하나의 presentation만 활성화될 수 있음
- ✅ 더 단순한 composition: 여러 property 대신 하나의 `ifLet`
- ✅ 더 명확한 코드: 모든 navigation flow가 단일 enum 안에 있음

**사용 시점:** 여러 presentation type을 가진 feature의 기본 선택.

```swift
@Reducer
struct Feature {
    @Reducer
    enum Destination {
        case sheet(SheetFeature)
        case dialog(ConfirmationDialog)
        case navigationDrill(DetailFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?  // ← Single source of truth
    }

    enum Action {
        case destination(PresentationAction<Destination.Action>)
        case view(ViewAction)
        case delegate(DelegateAction)
    }

    enum ViewAction {
        case showSheet
        case showDialog
        case showDetail
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(.showSheet):
                state.destination = .sheet(SheetFeature.State())
                return .none

            case .view(.showDialog):
                state.destination = .dialog(ConfirmationDialog.State())
                return .none

            case .view(.showDetail):
                state.destination = .navigationDrill(DetailFeature.State())
                return .none

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)  // ← Single composition point
    }
}
```

### 피해야 할 것: 여러 `@Presents` Property

❌ **이렇게 하지 마세요:** 각 destination마다 별도의 `@Presents` property를 두는 것

```swift
// ❌ Avoid this pattern
struct BadState {
    @Presents var sheetDestination: SheetFeature.State?
    @Presents var alertDestination: AlertState<AlertAction>?
    @Presents var navigationDestination: DetailFeature.State?
    // Multiple properties = complexity, harder to test
}
```

여러 property를 두면 다음과 같은 문제가 생깁니다:
- ✗ State 복잡성: 여러 presentation state를 관리해야 함
- ✗ 테스트 부담: property 조합을 검증해야 함
- ✗ 오류 발생 가능성: 여러 presentation이 동시에 표시되기 쉬움
- ✗ Reducer 잡음: 여러 `ifLet` 체인

### 기본 Destination 관리

```swift
@Reducer(state: .equatable)
public enum Destination {
    case detail(DetailReducer)
    case settings(SettingsReducer)
    case alert(AlertReducer)
}

// In main reducer
case .view(.didTapDetail):
    state.destination = .detail(DetailReducer.State())
    return .none

case .destination(.presented(.detail(.delegate(.didComplete)))):
    state.destination = nil
    return .send(.delegate(.userDidCompleteFlow))
```

## Alert 관리

```swift
public enum Alert: Equatable {
    case confirmDelete
    case retryAction
    case showError(Error)
}

case .view(.didTapDelete):
    state.alert = .confirmDelete
    return .none

case .alert(.presented(.confirmDelete)):
    return .send(.deleteItem)
```

## 여러 Presentation Destination

### Sheet, Popover, Navigation Drill-Down

```swift
@Reducer
struct MultipleDestinations {
    @Reducer
    enum Destination {
        case drillDown(Counter)
        case popover(Counter)
        case sheet(Counter)
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
    }

    enum Action {
        case destination(PresentationAction<Destination.Action>)
        case showDrillDown
        case showPopover
        case showSheet
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .showDrillDown:
                state.destination = .drillDown(Counter.State())
                return .none

            case .showPopover:
                state.destination = .popover(Counter.State())
                return .none

            case .showSheet:
                state.destination = .sheet(Counter.State())
                return .none

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}
```

### 여러 Presentation Modifier가 있는 View

```swift
struct MultipleDestinationsView: View {
    @Bindable var store: StoreOf<MultipleDestinations>

    var body: some View {
        Form {
            Button("Show drill-down") {
                store.send(.showDrillDown)
            }

            Button("Show popover") {
                store.send(.showPopover)
            }

            Button("Show sheet") {
                store.send(.showSheet)
            }
        }
        .navigationDestination(
            item: $store.scope(
                state: \.destination?.drillDown,
                action: \.destination.drillDown
            )
        ) { store in
            CounterView(store: store)
        }
        .popover(
            item: $store.scope(
                state: \.destination?.popover,
                action: \.destination.popover
            )
        ) { store in
            CounterView(store: store)
        }
        .sheet(
            item: $store.scope(
                state: \.destination?.sheet,
                action: \.destination.sheet
            )
        ) { store in
            CounterView(store: store)
        }
    }
}
```

## Alert와 다른 Destination 결합하기

```swift
@Reducer
struct Feature {
    @Reducer
    enum Destination {
        case alert(AlertState<Alert>)
        case detail(Detail)
        case settings(Settings)
    }

    @CasePathable
    enum Alert {
        case confirmDelete
        case confirmLogout
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
    }

    enum Action {
        case destination(PresentationAction<Destination.Action>)
        case showAlert(Alert)
        case showDetail
        case showSettings
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .showAlert(let alert):
                state.destination = .alert(alertState(for: alert))
                return .none

            case .showDetail:
                state.destination = .detail(Detail.State())
                return .none

            case .showSettings:
                state.destination = .settings(Settings.State())
                return .none

            case .destination(.presented(.alert(.confirmDelete))):
                state.destination = nil
                return .send(.deleteItem)

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    func alertState(for alert: Alert) -> AlertState<Alert> {
        switch alert {
        case .confirmDelete:
            return AlertState {
                TextState("Delete Item")
            } actions: {
                ButtonState(role: .destructive, action: .confirmDelete) {
                    TextState("Delete")
                }
                ButtonState(role: .cancel) {
                    TextState("Cancel")
                }
            }

        case .confirmLogout:
            return AlertState {
                TextState("Log Out")
            } actions: {
                ButtonState(role: .destructive, action: .confirmLogout) {
                    TextState("Log Out")
                }
            }
        }
    }
}
```

View:

```swift
struct FeatureView: View {
    @Bindable var store: StoreOf<Feature>

    var body: some View {
        VStack {
            // Content
        }
        .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
        .sheet(
            item: $store.scope(state: \.destination?.detail, action: \.destination.detail)
        ) { store in
            DetailView(store: store)
        }
        .sheet(
            item: $store.scope(state: \.destination?.settings, action: \.destination.settings)
        ) { store in
            SettingsView(store: store)
        }
    }
}
```
