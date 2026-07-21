# View Composition Patterns

ForEach scoping, child feature, 그리고 optional child view를 다룹니다.

## Scoped Store를 사용하는 ForEach

### IdentifiedArray Pattern

```swift
struct TodosView: View {
    let store: StoreOf<Todos>

    var body: some View {
        List {
            ForEach(
                store.scope(state: \.todos, action: \.todos)
            ) { store in
                TodoRowView(store: store)
            }
        }
    }
}
```

대응하는 reducer:

```swift
@Reducer
struct Todos {
    @ObservableState
    struct State: Equatable {
        var todos: IdentifiedArrayOf<Todo.State> = []
    }

    enum Action {
        case todos(IdentifiedActionOf<Todo>)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            // Parent-level logic
            return .none
        }
        .forEach(\.todos, action: \.todos) {
            Todo()
        }
    }
}
```

### 필터링된 컬렉션

```swift
struct TodosView: View {
    let store: StoreOf<Todos>

    var body: some View {
        List {
            ForEach(
                store.scope(state: \.filteredTodos, action: \.todos)
            ) { store in
                TodoRowView(store: store)
            }
        }
    }
}
```

computed property가 있는 대응하는 state:

```swift
@ObservableState
struct State: Equatable {
    var todos: IdentifiedArrayOf<Todo.State> = []
    var filter: Filter = .all

    var filteredTodos: IdentifiedArrayOf<Todo.State> {
        switch filter {
        case .all:
            return todos
        case .active:
            return todos.filter { !$0.isComplete }
        case .completed:
            return todos.filter { $0.isComplete }
        }
    }
}
```

## Child Feature Scope

### 단일 Child Feature

```swift
struct TwoCountersView: View {
    let store: StoreOf<TwoCounters>

    var body: some View {
        VStack {
            CounterView(
                store: store.scope(state: \.counter1, action: \.counter1)
            )

            CounterView(
                store: store.scope(state: \.counter2, action: \.counter2)
            )
        }
    }
}
```

대응하는 reducer:

```swift
@Reducer
struct TwoCounters {
    @ObservableState
    struct State: Equatable {
        var counter1 = Counter.State()
        var counter2 = Counter.State()
    }

    enum Action {
        case counter1(Counter.Action)
        case counter2(Counter.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.counter1, action: \.counter1) {
            Counter()
        }
        Scope(state: \.counter2, action: \.counter2) {
            Counter()
        }
    }
}
```

## Optional Child Feature

### ifLet 사용

```swift
struct OptionalCounterView: View {
    let store: StoreOf<OptionalCounter>

    var body: some View {
        VStack {
            if let store = store.scope(state: \.counter, action: \.counter) {
                CounterView(store: store)
            } else {
                Text("Counter not loaded")
            }

            Button("Toggle Counter") {
                store.send(.toggleCounterButtonTapped)
            }
        }
    }
}
```

대응하는 reducer:

```swift
@Reducer
struct OptionalCounter {
    @ObservableState
    struct State: Equatable {
        var counter: Counter.State?
    }

    enum Action {
        case counter(Counter.Action)
        case toggleCounterButtonTapped
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .toggleCounterButtonTapped:
                state.counter = state.counter == nil ? Counter.State() : nil
                return .none

            case .counter:
                return .none
            }
        }
        .ifLet(\.counter, action: \.counter) {
            Counter()
        }
    }
}
```

## 모범 사례

1. **Store scope** - child feature에는 `store.scope(state:action:)`을 사용
2. **Computed property** - view가 아니라 state에서 컬렉션을 필터링/변환
3. **IdentifiedArrayOf** - child feature의 컬렉션에 사용
4. **`.forEach`** - 컬렉션을 위해 reducer를 구성
5. **`.ifLet`** - optional child feature를 위해 reducer를 구성
6. **View 내 scope** - 올바른 observation을 위해 view body에서 scoped store를 생성
