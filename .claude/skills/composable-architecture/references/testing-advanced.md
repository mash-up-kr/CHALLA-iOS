# 고급 테스트 패턴

시간 제어, keypath matching, exhaustivity, 복잡한 시나리오 등 고급 테스트 기법입니다.

## Given-When-Then 패턴

```swift
@Test("user can save form with valid data")
func testSaveFormWithValidData() async {
    // GIVEN: Valid form data
    let validData = FormData.test()
    let store = makeStore()

    // WHEN: User submits form
    await store.send(.view(.didChangeData(validData)))
    await store.send(.view(.didTapSave))

    // THEN: Form is saved successfully
    await store.receive(.didSaveData(.success(()))) {
        $0.isSaved = true
    }
}
```

## State Machine 테스트

```swift
@Test("transitions through loading states correctly")
func testLoadingStateTransitions() async {
    let store = makeStore()

    // Initial state
    #expect(store.state.loadingState == .idle)

    // Start loading
    await store.send(.view(.onAppear)) {
        $0.loadingState = .loading
    }

    // Load success
    await store.receive(.didLoadData(.success([]))) {
        $0.loadingState = .loaded([])
    }
}
```

## Edge Case 테스트

```swift
@Test("handles empty data gracefully")
func testEmptyData() async {
    let store = makeStore {
        $0.apiClient.fetchData = { [] }
    }

    await store.send(.view(.onAppear))
    await store.receive(.didLoadData(.success([]))) {
        $0.data = []
        $0.isEmpty = true
        $0.showEmptyState = true
    }
}
```

## 시간 기반 테스트

### Debouncing

```swift
@Test("debounces user input correctly")
func testDebouncedInput() async {
    let store = makeStore {
        $0.continuousClock = ImmediateClock()
    }

    // Send rapid input
    await store.send(.view(.didChangeText("a")))
    await store.send(.view(.didChangeText("ab")))
    await store.send(.view(.didChangeText("abc")))

    // Should only receive debounced action
    await store.receive(.searchDebounced("abc"))
}
```

### 정밀한 시간 제어를 위한 TestClock

시간 진행을 정밀하게 제어해야 할 때는 `TestClock`을 사용하세요.

```swift
@Test("timer advances correctly")
func testTimer() async {
    let clock = TestClock()

    let store = TestStore(initialState: Timer.State()) {
        Timer()
    } withDependencies: {
        $0.continuousClock = clock
    }

    // Start timer
    await store.send(.toggleTimerButtonTapped) {
        $0.isTimerActive = true
    }

    // Advance time by 1 second
    await clock.advance(by: .seconds(1))
    await store.receive(\.timerTick) {
        $0.secondsElapsed = 1
    }

    // Advance time by multiple seconds
    await clock.advance(by: .seconds(3))
    await store.receive(\.timerTick) {
        $0.secondsElapsed = 2
    }
    await store.receive(\.timerTick) {
        $0.secondsElapsed = 3
    }
    await store.receive(\.timerTick) {
        $0.secondsElapsed = 4
    }
}
```

### TestClock과 ImmediateClock 비교

- **ImmediateClock**: 시간 기반 작업이 모두 즉시 완료됩니다
    - 용도: debouncing, delay, 단순 timeout
    - 실제 시간이 흐르지 않는 빠른 테스트

- **TestClock**: 시간 진행을 수동으로 제어합니다
    - 용도: timer, interval, 정밀한 시간 기반 동작
    - 정확한 타이밍 시퀀스 테스트

```swift
// ImmediateClock example - delays complete instantly
@Test("loads data after delay")
func testDelayedLoad() async {
    let store = makeStore {
        $0.continuousClock = ImmediateClock()
    }

    await store.send(.loadData)
    await store.receive(\.dataLoaded)  // Immediate, no waiting
}

// TestClock example - control time advancement
@Test("polls every 5 seconds")
func testPolling() async {
    let clock = TestClock()
    let store = makeStore {
        $0.continuousClock = clock
    }

    await store.send(.startPolling)

    await clock.advance(by: .seconds(5))
    await store.receive(\.pollResponse)

    await clock.advance(by: .seconds(5))
    await store.receive(\.pollResponse)
}
```

## KeyPath 기반 Action Receiving

더 간결한 action matching을 위해 keypath 문법을 사용하세요.

```swift
// Instead of this:
await store.receive(.numberFactResponse(.success("Test fact"))) {
    $0.fact = "Test fact"
}

// Use this:
await store.receive(\.numberFactResponse.success) {
    $0.fact = "Test fact"
}
```

### 복합 KeyPath

```swift
// Nested actions
await store.receive(\.destination.presented.detail.delegate.didComplete)

// ForEach actions
await store.receive(\.todos[id: todoID].toggleCompleted)

// Path actions
await store.receive(\.path[id: screenID].screenA.didSave)
```

### 부분 매칭

```swift
// Match any success response
await store.receive(\.numberFactResponse.success) {
    $0.fact = "Test fact"
}

// Match any failure response
await store.receive(\.numberFactResponse.failure) {
    $0.alert = AlertState { TextState("Error") }
}

// Match delegate action
await store.receive(\.delegate) {
    // State changes
}
```

## Test Exhaustivity 제어

TestStore는 모든 state 변경과 수신된 action을 명시적으로 assert해야 하는지를 제어하는 `exhaustivity` property를 가지고 있습니다. 기본적으로 exhaustivity는 `.on`이며, 이는 모든 state 변경을 assert해야 한다는 뜻입니다. 특정 결과만 신경 쓰는 복잡한 flow에서는 `.off`로 설정하세요.

### `.off`를 사용해야 하는 경우

다음의 경우 `store.exhaustivity = .off`를 사용하세요.

1. **복잡한 비동기 flow** - 테스트와 관련 없는 중간 state 변경이 많은 flow를 테스트할 때
2. **서드파티 state** - `@FetchOne`, `@Fetch` 등 자체적으로 state를 관리하는 property wrapper를 사용할 때
3. **결과에 집중** - 모든 중간 단계가 아니라 최종 결과만 신경 쓸 때
4. **통합(integration) 스타일 테스트** - 모든 state 변경을 세세하게 관리하지 않고 end-to-end flow를 테스트할 때

### 패턴

```swift
@Test("available status triggers sync when identity exists")
func availableStatusWithIdentity() async {
    let testIdentity = StoredAppleIdentity(appleUserId: "test-user-id")

    let store = makeStore {
        $0.appleIdentityStore.load = { testIdentity }
    }

    // Turn off exhaustivity - we only care about specific actions being sent
    store.exhaustivity = .off

    await store.send(.iCloudAccountStatusChanged(.available))

    // Assert only the actions we care about
    await store.receive(\.fetchUnclaimedShareItems)
    await store.receive(\.ensureSharedItemSubscription)

    // Other state changes and actions can happen without failing the test
}
```

### State 검증과 함께 사용하기

exhaustivity가 off인 상태에서도 특정 state를 검증할 수 있습니다.

```swift
@Test("edit mode populates from existing item")
func editModePopulatesFromExisting() async {
    let existingItem = makeTestExistingItem()
    let store = makeStore(initialState: .editing(existingItem))

    store.exhaustivity = .off

    #expect(store.state.mode == .edit(existingItem: existingItem))
    #expect(store.state.itemTypeEditor != nil)

    // Can check specific state properties without asserting every change
    if case .link(let linkState) = store.state.itemTypeEditor {
        #expect(linkState.urlInput == "https://example.com")
        #expect(linkState.preview?.title == "Example")
    }
}
```

### 모범 사례

**해야 할 것**:
- 최종 결과에 집중하는 통합 테스트에는 exhaustivity를 off로 사용하세요
- 여전히 신경 쓰는 핵심 state 변경과 action은 assert하세요
- 내부적으로 state를 관리하는 @Fetch/@FetchOne을 다룰 때 사용하세요
- 복잡한 테스트에서는 exhaustivity를 왜 off로 했는지 문서화하세요

**하지 말아야 할 것**:
- state 변경을 고민하지 않으려는 도구로 사용하지 마세요
- 모든 state가 중요한 단순한 단위 테스트에서 끄지 마세요
- exhaustivity가 off라는 이유로 중요한 결과를 assert하는 것을 잊지 마세요
- 버그나 예기치 않은 state 변경을 숨기기 위해 사용하지 마세요

### 예시: @FetchOne으로 테스트하기

```swift
@Test("onAppear sets default list when no selection")
func onAppearSetsDefaultList() async {
    let inboxListID = UUID()
    let store = makeStore {
        $0.defaultDatabase.read = { db in
            return StashItemList(id: inboxListID, name: "Inbox", ...)
        }
    }

    // @FetchOne property wrapper manages its own state internally
    store.exhaustivity = .off

    await store.send(.view(.onAppear))
    await store.receive(.setSelectedListID(inboxListID))

    // We don't need to assert $selectedList changes because @FetchOne handles it
}
```
