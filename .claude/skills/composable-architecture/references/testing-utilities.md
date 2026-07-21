# 테스트 유틸리티

test data 패턴, 구성, confirmation dialog, dependency mocking, @Shared state 테스트입니다.

## Test Data 패턴

### Test Data Factory

```swift
extension Item {
    static func test(
        id: Int = 1,
        name: String = "Test Item",
        isEnabled: Bool = true
    ) -> Self {
        Self(
            id: id,
            name: name,
            isEnabled: isEnabled
        )
    }
}
```

### Test Data 배열

```swift
extension Array where Element == Item {
    static func test(count: Int = 3) -> [Item] {
        (1...count).map { Item.test(id: $0, name: "Item \($0)") }
    }
}
```

### Test Data 상수 (권장)

새로운 UUID를 매번 생성하는 대신 재현 가능한 테스트를 위해 enum 기반 ID 상수를 사용하세요.

```swift
// ✅ Good: Consistent test data constants
enum TestData {
    static let itemId1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let itemId2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
}

@Test("sets item as favorite")
func testSetFavorite() async {
    let setFavoriteCalled = LockIsolated<UUID?>(nil)
    // Use constant - reproducible
    await store.send(.view(.onSetFavoriteTapped(TestData.itemId1)))
    #expect(setFavoriteCalled.value == TestData.itemId1)
}

// ❌ Avoid: Creating new UUIDs each test run
let itemId = UUID()  // Different every run, harder to debug
```

## 테스트 구성

### MARK를 이용한 테스트 그룹화

```swift
@Suite("Feature Name")
@MainActor
struct FeatureNameTests {

    // MARK: - Setup
    private func makeStore() -> TestStoreOf<Reducer> { ... }

    // MARK: - Initialization Tests
    @Test("initializes with correct default state")
    func testInitialization() async { ... }

    // MARK: - User Interaction Tests
    @Test("responds to user taps")
    func testUserInteraction() async { ... }

    // MARK: - Data Loading Tests
    @Test("loads data on appear")
    func testDataLoading() async { ... }

    // MARK: - Error Handling Tests
    @Test("handles network errors")
    func testErrorHandling() async { ... }

    // MARK: - Navigation Tests
    @Test("navigates to detail screen")
    func testNavigation() async { ... }
}
```

### 테스트 문서화

```swift
/// Tests the initialization of the EditShift feature.
/// Verifies that:
/// - Shift is loaded correctly
/// - State is set up with correct initial values
/// - Properties are properly initialized
@Test("onAppear loads shift successfully")
func testOnAppearLoadsShift() async { ... }
```

## ConfirmationDialogState 테스트

`ConfirmationDialogState`를 사용하는 feature를 테스트할 때는 다음 패턴을 따르세요.

### 기본 패턴

```swift
@Test("confirmation dialog action deletes with preserve")
func testConfirmationDialogAction() async {
    var state = Feature.State()
    state.confirmDeleteBundleId = testBundleId
    state.confirmationDialog = .deleteBundle(name: "Test", itemCount: 2)

    let deleteCalled = LockIsolated<(UUID, Bool)?>(nil)

    let store = TestStore(initialState: state) {
        Feature()
    } withDependencies: {
        $0.bundleClient.delete = { id, preserveItems in
            deleteCalled.setValue((id, preserveItems))
        }
    }

    // Send the presented action and expect BOTH state changes
    await store.send(.confirmationDialog(.presented(.moveItemsToInbox))) {
        $0.confirmDeleteBundleId = nil
        $0.confirmationDialog = nil  // Dialog clears on action
    }

    // CRITICAL: Exhaust effects from .run blocks
    await store.finish()

    #expect(deleteCalled.value?.0 == testBundleId)
    #expect(deleteCalled.value?.1 == true)
}
```

### 핵심 포인트

1. **두 state property를 모두 비워야 합니다**: dialog action이 발생하면 `confirmationDialog = nil`과 tracking ID를 함께 `nil`로 설정하세요
2. **`await store.finish()`를 사용하세요**: action을 보낸 후에는 `.run { }` block에서 발생한 effect를 모두 소진(exhaust)해야 합니다
3. **Dialog dismiss**: `.dismiss` action의 경우에는 `confirmationDialog`만 초기화됩니다 (tracking ID는 초기화되지 않습니다)

```swift
await store.send(.confirmationDialog(.dismiss)) {
    $0.confirmationDialog = nil
    // Note: confirmDeleteBundleId stays set (becomes stale but harmless)
}
```

## Dependency Mocking의 완전성

reducer가 새로운 dependency를 호출하도록 수정할 때는 **항상 그에 대응하는 test mock도 업데이트하세요**.

### 흔한 함정

```swift
// Reducer calls TWO dependencies:
case .view(.saveTapped):
    return .run { send in
        try await bundleClient.update(id, name, color)
        try await bundleClient.updateTemporary(id, isTemporary)  // NEW!
        await send(.delegate(.saved))
    }

// ❌ Test only mocks ONE - will fail with unimplemented dependency
let store = TestStore(...) {
    $0.bundleClient.update = { ... }
    // Missing: $0.bundleClient.updateTemporary
}

// ✅ Mock ALL dependencies called by the action
let store = TestStore(...) {
    $0.bundleClient.update = { ... }
    $0.bundleClient.updateTemporary = { _, _ in }  // Added!
}
```

### 규칙

reducer에 dependency 호출을 추가했다면, 기존 테스트를 grep해서 mock을 추가하세요.

## LockIsolated 패턴

테스트에서 thread-safe하게 값을 캡처하려면 `LockIsolated`를 사용하세요.

### setValue()와 withLock 비교

```swift
// ✅ Preferred: Clean setter
let capturedId = LockIsolated<UUID?>(nil)
$0.itemClient.setFavorite = { id in
    capturedId.setValue(id)
}
#expect(capturedId.value == expectedId)

// Also valid: withLock for complex mutations
let callHistory = LockIsolated<[String]>([])
callHistory.withLock { $0.append("called") }
```

### Boolean 추적

```swift
let wasCalled = LockIsolated(false)
$0.client.someMethod = {
    wasCalled.setValue(true)
}
#expect(wasCalled.value == true)
```

## @Shared State 변경 테스트

### effect 이후 store.assert { } 사용하기

`@Shared` state를 변경하는 effect를 테스트할 때는, effect가 완료된 후 `store.assert { }`로 state를 검증하세요.

```swift
@Test("confirm action enables feature via Shared")
func testConfirmEnablesFeature() async {
    var state = Feature.State()
    state.confirmationAlert = FeatureHelper.confirmationAlertState()

    let store = TestStore(initialState: state) {
        Feature()
    } withDependencies: {
        $0.itemClient.setFavorite = { _ in }
    }

    // Action triggers effect that modifies @Shared
    await store.send(.confirmationAlert(.presented(.confirm(itemId: nil)))) {
        $0.confirmationAlert = nil
    }

    // Verify @Shared state after effect completes
    store.assert {
        $0.$featureEnabled.withLock { $0 = true }
    }
}
```

## 요약

**핵심 원칙**:
1. 테스트 구성을 위해 SwiftTesting의 `@Suite`와 `@Test`를 사용하세요
2. 기본 test dependency를 갖춘 재사용 가능한 `makeStore` helper를 만드세요
3. 시간 기반 테스트에는 `ImmediateClock`을 사용하세요
4. closure assertion으로 state 변경을 명시적으로 테스트하세요
5. `.test()` factory method로 dependency를 mock하세요
6. 성공 경로와 실패 경로를 모두 테스트하세요
7. navigation과 presentation state 변경을 검증하세요
8. 일관된 test data를 위해 test data factory를 사용하세요
9. MARK 주석으로 테스트를 구성하세요
10. 복잡한 테스트는 주석으로 문서화하세요
11. `.run` block에서 발생한 effect를 소진하려면 `await store.finish()`를 사용하세요
12. 새로운 dependency 호출을 추가할 때는 모든 test mock을 업데이트하세요
13. 더 깔끔한 값 캡처를 위해 `LockIsolated.setValue()`를 사용하세요
14. effect 이후 @Shared state를 검증하려면 `store.assert { }`를 사용하세요
15. `UUID()` 대신 test data 상수(예: `BundleTestData.bundleId1`)를 사용하세요
