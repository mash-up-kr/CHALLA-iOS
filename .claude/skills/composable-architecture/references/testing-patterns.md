# 테스트 패턴

TCA에서 action, state 변경, dependency, error, presentation을 테스트하기 위한 핵심 패턴입니다.

## Action 테스트

### 기본 Action 테스트

```swift
@Test("onAppear triggers data loading")
func testOnAppear() async {
    let store = makeStore()

    await store.send(.view(.onAppear))
    await store.receive(.loadData) {
        $0.isLoading = true
    }
}
```

### 성공 Flow 테스트

```swift
@Test("successful data loading flow")
func testSuccessfulDataLoading() async {
    let testData = [Item(id: 1, name: "Test")]
    let store = makeStore {
        $0.apiClient.fetchData = { testData }
    }

    await store.send(.view(.onAppear))
    await store.receive(.loadData) {
        $0.isLoading = true
    }
    await store.receive(.didLoadData(.success(testData))) {
        $0.isLoading = false
        $0.data = testData
    }
}
```

### Delegate Action 테스트

```swift
@Test("notifies parent on completion")
func testDelegateNotification() async {
    let store = makeStore()

    await store.send(.view(.didTapSave))
    await store.receive(.delegate(.userDidCompleteFlow))
}
```

### State 변경 없이 Receive하기

**중요**: state를 변경하지 않는 action을 받을 때는 closure를 완전히 생략하세요.

```swift
// ✅ No state change expected - omit closure
await store.receive(\.delegate.bundleSelected)
await store.receive(\.delegate.cancelled)

// ❌ WRONG - causes "Expected state to change, but no change occurred"
await store.receive(\.delegate.bundleSelected) { _ in }
await store.receive(\.delegate.cancelled) { _ in }
```

`receive`의 closure는 TestStore에게 state 변경이 있을 것이라고 알려주는 역할을 합니다. 변경이 없는데 `{ _ in }`이나 `{ $0 }`를 사용하면 테스트가 실패합니다.

## State 검증

### 기본 State 검증

```swift
await store.send(.view(.didTapSave)) {
    $0.isLoading = true
    $0.canSave = false
}
```

### 복합 State 검증

```swift
await store.receive(.didLoadData(.success(testData))) {
    $0.isLoading = false
    $0.data = testData
    $0.isEmpty = false
    $0.canSave = true
}
```

### Computed Property 테스트

```swift
@Test("computed properties work correctly")
func testComputedProperties() async {
    var state = Reducer.State()

    // Test empty state
    #expect(state.isEmpty == true)
    #expect(state.canSave == false)

    // Test with data
    state.data = [Item(id: 1, name: "Test")]
    #expect(state.isEmpty == false)
    #expect(state.canSave == true)
}
```

## Dependency 테스트

### Dependency 검증

```swift
@Test("tracks analytics events")
func testAnalyticsTracking() async {
    var trackedEvents: [AnalyticsEvent] = []
    let store = makeStore {
        $0.analytics = .test { event in
            trackedEvents.append(event)
        }
    }

    await store.send(.view(.onAppear))

    #expect(trackedEvents.count == 1)
    #expect(trackedEvents.first == .screenViewed)
}
```

### 다중 Dependency 테스트

```swift
@Test("coordinates multiple dependencies")
func testMultipleDependencies() async {
    var analyticsEvents: [AnalyticsEvent] = []
    var apiCalls: [String] = []

    let store = makeStore {
        $0.analytics = .test { event in
            analyticsEvents.append(event)
        }
        $0.apiClient = .test { endpoint in
            apiCalls.append(endpoint)
            return TestData()
        }
    }

    await store.send(.view(.onAppear))

    #expect(apiCalls.contains("fetchData"))
    #expect(analyticsEvents.contains(.screenViewed))
}
```

## Error 테스트

### Error State 검증

```swift
@Test("shows error alert on failure")
func testErrorAlert() async {
    let error = NetworkError.timeout
    let store = makeStore {
        $0.apiClient.fetchData = { throw error }
    }

    await store.send(.view(.onAppear))
    await store.receive(.didLoadData(.failure(error))) {
        $0.alert = .error(error)
    }

    #expect(store.state.alert != nil)
}
```

### Error 복구 테스트

```swift
@Test("can retry after error")
func testErrorRetry() async {
    var callCount = 0
    let store = makeStore {
        $0.apiClient.fetchData = {
            callCount += 1
            if callCount == 1 {
                throw NetworkError.timeout
            }
            return [Item(id: 1, name: "Test")]
        }
    }

    // First attempt fails
    await store.send(.view(.onAppear))
    await store.receive(.didLoadData(.failure(NetworkError.timeout)))

    // Retry succeeds
    await store.send(.alert(.presented(.retry)))
    await store.receive(.didLoadData(.success([Item(id: 1, name: "Test")])))

    #expect(callCount == 2)
}
```

## Presentation 테스트

### Destination 테스트

```swift
@Test("navigates to detail screen")
func testNavigationToDetail() async {
    let store = makeStore()

    await store.send(.view(.didTapDetail)) {
        $0.destination = .detail(DetailReducer.State())
    }
}

@Test("handles detail completion")
func testDetailCompletion() async {
    let store = makeStore()

    // Navigate to detail
    await store.send(.view(.didTapDetail))

    // Complete detail flow
    await store.send(.destination(.presented(.detail(.delegate(.didComplete))))) {
        $0.destination = nil
    }
    await store.receive(.delegate(.userDidCompleteFlow))
}
```

### Alert 테스트

```swift
@Test("shows confirmation alert")
func testConfirmationAlert() async {
    let store = makeStore()

    await store.send(.view(.didTapDelete)) {
        $0.alert = .confirmDelete
    }

    await store.send(.alert(.presented(.confirmDelete))) {
        $0.alert = nil
    }
    await store.receive(.deleteItem)
}
```

## 비동기 테스트

### 비동기 Effect 테스트

```swift
@Test("handles async operations")
func testAsyncOperations() async {
    let expectation = Expectation(description: "Async operation completes")
    let store = makeStore {
        $0.apiClient.fetchData = {
            try await Task.sleep(nanoseconds: 1_000_000)
            expectation.fulfill()
            return [Item(id: 1, name: "Test")]
        }
    }

    await store.send(.view(.onAppear))
    await store.receive(.didLoadData(.success([Item(id: 1, name: "Test")])))

    await expectation.await()
}
```

### Effect 취소 테스트

```swift
@Test("cancels effects on dismiss")
func testEffectCancellation() async {
    var isCancelled = false
    let store = makeStore {
        $0.apiClient.fetchData = {
            try await Task.sleep(nanoseconds: 1_000_000)
            if Task.isCancelled {
                isCancelled = true
                throw CancellationError()
            }
            return []
        }
    }

    await store.send(.view(.onAppear))
    await store.send(.view(.onDisappear))

    try await Task.sleep(nanoseconds: 2_000_000)
    #expect(isCancelled == true)
}
```

## @Shared State 테스트

### 테스트 격리를 위한 .dependencies Trait 사용

각 테스트가 항상 새로운 dependency를 받도록 `@Suite`에 `.dependencies`를 추가하세요.

```swift
@MainActor
@Suite(
    "SettingsFeature",
    .dependency(\.continuousClock, ImmediateClock()),
    .dependencies  // Ensures fresh dependencies per test for determinism
)
struct SettingsFeatureTests {
    // ...
}
```

`.dependencies`가 없으면 테스트가 state를 공유하게 되어 비결정적인 결과가 나올 수 있습니다.

### 테스트에서 @Shared 설정하기

state를 초기화하고 검증하려면 test scope에서 `@Shared` 변수를 선언하세요.

```swift
@Test("enables notifications when toggled on")
func testEnablesNotifications() async {
    // Declare @Shared at test scope for verification
    @Shared(.appStorage("notificationsEnabled")) var notificationsEnabled = false

    let store = TestStore(initialState: SettingsFeature.State()) {
        SettingsFeature()
    } withDependencies: {
        $0.notificationClient.requestAuthorization = { true }
    }

    await store.send(.view(.notificationToggleTapped))
    await store.receive(\.delegate.notificationsConfigured) {
        // Assert @Shared mutation in state closure
        $0.$notificationsEnabled.withLock { $0 = true }
    }

    // Can also verify outside store
    #expect(notificationsEnabled == true)
}
```

### receive에서 @Shared 변경 Assert하기

effect가 `@Shared` state를 변경하면, 그 변경을 `receive` closure에서 assert하세요.

```swift
await store.receive(\.delegate.settingsSaved) {
    $0.isSaving = false
    // Assert @Shared mutations using withLock
    $0.$darkModeEnabled.withLock { $0 = true }
    $0.$accentColor.withLock { $0 = "blue" }
}
```

**중요:** TestStore가 `@Shared` 변경을 관찰하려면, `@Shared` property가 State에 선언되어 `.run` closure 전에 캡처되어야 합니다. effect 내부에 `@Shared`를 선언하면 TestStore가 관찰할 수 없는 별개의 인스턴스가 만들어집니다.

### @Shared Toggle Action 테스트

```swift
@Test("dark mode toggle updates shared setting")
func testDarkModeToggle() async {
    @Shared(.appStorage("darkModeEnabled")) var darkModeEnabled = false

    let store = TestStore(initialState: AppearanceFeature.State()) {
        AppearanceFeature()
    }

    await store.send(.view(.darkModeToggled(true))) {
        $0.$darkModeEnabled.withLock { $0 = true }
    }
    await store.finish()
}
```
