# Navigation 기초

path reducer와 programmatic navigation을 사용하는 NavigationStack 패턴입니다.

## Path Reducer를 사용한 NavigationStack

### 기본 패턴

```swift
@Reducer
struct NavigationDemo {
    @Reducer
    enum Path {
        case screenA(ScreenA)
        case screenB(ScreenB)
        case screenC(ScreenC)
    }

    @ObservableState
    struct State: Equatable {
        var path = StackState<Path.State>()
    }

    enum Action {
        case path(StackActionOf<Path>)
        case popToRoot
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .popToRoot:
                state.path.removeAll()
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
```

### store.case 패턴을 사용하는 View

```swift
struct NavigationDemoView: View {
    @Bindable var store: StoreOf<NavigationDemo>

    var body: some View {
        NavigationStack(
            path: $store.scope(state: \.path, action: \.path)
        ) {
            RootView()
        } destination: { store in
            switch store.case {
            case let .screenA(store):
                ScreenAView(store: store)

            case let .screenB(store):
                ScreenBView(store: store)

            case let .screenC(store):
                ScreenCView(store: store)
            }
        }
    }
}
```

## Navigation Action

### Stack에 Push하기

```swift
case .view(.didTapNavigateToDetail):
    state.path.append(.detail(Detail.State()))
    return .none

case .view(.didTapNavigateToSettings):
    state.path.append(.settings(Settings.State(id: state.selectedId)))
    return .none
```

### Stack에서 Pop하기

```swift
// Pop one screen
case .view(.didTapBack):
    state.path.removeLast()
    return .none

// Pop to root
case .view(.didTapPopToRoot):
    state.path.removeAll()
    return .none

// Pop to specific index
case .view(.didTapPopToFirst):
    state.path.removeAll(after: 0)
    return .none
```

### Programmatic Dismiss

child feature가 스스로 dismiss하도록 `@Dependency(\.dismiss)`를 사용하세요.

```swift
@Reducer
struct DetailFeature {
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(.didTapClose):
                return .run { _ in
                    await self.dismiss()
                }

            case .view(.didSave):
                return .concatenate(
                    .send(.delegate(.didSave)),
                    .run { _ in await self.dismiss() }
                )
            }
        }
    }
}
```

## Child Action 처리하기

### Delegate Action에 응답하기

```swift
case .path(.element(id: _, action: .detail(.delegate(.didSave)))):
    // Detail screen saved, pop it
    state.path.removeLast()
    return .send(.refreshData)

case .path(.element(id: _, action: .settings(.delegate(.didLogout)))):
    // Settings logged out, pop to root
    state.path.removeAll()
    return .send(.delegate(.userDidLogout))
```

### Navigation Stack 검사하기

```swift
case .view(.didTapSave):
    // Check if we're in a specific screen
    guard state.path.last(where: { $0.is(\.detail) }) != nil else {
        return .none
    }
    return .send(.path(.element(id: state.path.ids.last!, action: .detail(.save))))
```

## Enum Reducer Conformance

**중요**: `@Reducer enum Path`를 사용할 때는 extension을 통해 protocol conformance를 추가하세요.

```swift
@Reducer
struct NavigationDemo {
    @Reducer
    enum Path {
        case screenA(ScreenA)
        case screenB(ScreenB)
    }
}

// Extension must be at file scope
extension NavigationDemo.Path: Equatable {}
```

## Best Practices

1. **`@Reducer enum Path` 사용** - type-safe한 navigation destination을 위해
2. **`StackState` 사용** - navigation stack state를 관리하기 위해
3. **`.forEach(\.path, action: \.path)` 사용** - path reducer composition을 위해
4. **`@Dependency(\.dismiss)` 사용** - child feature가 스스로 dismiss하도록
5. **delegate action 처리** - child 완료에 따라 stack을 pop하거나 navigate
6. **Extension conformance** - enum reducer에 extension을 통해 `Equatable`을 추가
