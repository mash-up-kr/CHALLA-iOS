# View Binding Patterns

양방향 binding을 위한 store 기반 기본 view와 @Bindable pattern.

## 기본 Store 기반 View

```swift
struct CounterView: View {
    let store: StoreOf<Counter>

    var body: some View {
        HStack {
            Button {
                store.send(.decrementButtonTapped)
            } label: {
                Image(systemName: "minus")
            }

            Text("\(store.count)")
                .monospacedDigit()

            Button {
                store.send(.incrementButtonTapped)
            } label: {
                Image(systemName: "plus")
            }
        }
    }
}
```

## 양방향 Binding을 위한 @Bindable

SwiftUI 컨트롤이 store state에 직접 binding될 수 있도록 하려면 `@Bindable`을 사용하세요:

```swift
struct BindingFormView: View {
    @Bindable var store: StoreOf<BindingForm>

    var body: some View {
        Form {
            TextField("Type here", text: $store.text)

            Toggle("Disable other controls", isOn: $store.toggleIsOn)

            Stepper(
                "Max slider value: \(store.stepCount)",
                value: $store.stepCount,
                in: 0...100
            )

            Slider(value: $store.sliderValue, in: 0...Double(store.stepCount))
        }
    }
}
```

### Action과 함께 사용하는 @Bindable

값이 변경될 때 커스텀 로직이 필요한 action의 경우:

```swift
struct SettingsView: View {
    @Bindable var store: StoreOf<Settings>

    var body: some View {
        Toggle(
            "Notifications",
            isOn: $store.notificationsEnabled.sending(\.toggleNotifications)
        )

        Stepper(
            "\(store.count)",
            value: $store.count.sending(\.stepperChanged)
        )
    }
}
```

대응하는 reducer:

```swift
enum Action: BindableAction {
    case binding(BindingAction<State>)
    case toggleNotifications
    case stepperChanged

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .toggleNotifications:
                // Custom logic when toggle changes
                return .send(.requestNotificationPermission)

            case .stepperChanged:
                // Custom logic when stepper changes
                return .send(.trackCountChange)

            case .binding:
                return .none
            }
        }
    }
}
```

## State 변경 관찰

### State 직접 접근

```swift
struct StatusView: View {
    let store: StoreOf<Status>

    var body: some View {
        VStack {
            if store.isLoading {
                ProgressView()
            } else if let error = store.error {
                ErrorView(error: error)
            } else {
                ContentView(data: store.data)
            }
        }
    }
}
```

### State 기반 애니메이션

```swift
struct AnimatedCounterView: View {
    let store: StoreOf<Counter>

    var body: some View {
        Text("\(store.count)")
            .font(.largeTitle)
            .animation(.spring(), value: store.count)
    }
}
```

## View Action

### onAppear Pattern

```swift
struct FeatureView: View {
    let store: StoreOf<Feature>

    var body: some View {
        VStack {
            // Content
        }
        .onAppear {
            store.send(.view(.onAppear))
        }
    }
}
```

### View 생명주기를 위한 task Pattern

```swift
struct FeatureView: View {
    let store: StoreOf<Feature>

    var body: some View {
        VStack {
            // Content
        }
        .task {
            await store.send(.view(.runTasks)).finish()
        }
        .onAppear {
            store.send(.view(.onAppear))
        }
    }
}
```

`.task` modifier는 view가 사라질 때 effect를 자동으로 취소하므로, view의 생명주기 동안 계속 실행되어야 하는 streaming effect에 이상적입니다.

## 모범 사례

1. **`let store` 사용** - store는 view 내에서 immutable해야 합니다
2. **`@Bindable` 사용** - SwiftUI 컨트롤과의 양방향 binding을 위해
3. **사용자 이벤트를 위한 Action** - 사용자 상호작용에 대해 `.view` action을 전송
4. **lifetime effect를 위한 `.task`** - 자동으로 취소되어야 하는 streaming effect에 사용
5. **일회성 작업을 위한 `.onAppear`** - 초기 데이터 로딩에 사용
