# 테스트 기초

TestStore와 SwiftTesting으로 TCA feature를 테스트하기 위한 핵심 요구 사항과 설정 패턴입니다.

## Equatable Conformance 요구 사항

**중요**: `TestStore`로 TCA reducer를 테스트하려면 reducer의 `State`가 **반드시** `Equatable`을 준수해야 합니다. 이는 TCA 테스트의 필수 요구 사항입니다.

**핵심 규칙**:
1. 테스트하려는 reducer의 모든 `State` struct는 `Equatable`을 준수해야 합니다
2. 해당 `State` 내부의 **모든 property 타입**도 `Equatable`을 준수해야 합니다
3. 여기에는 nested된 child feature state도 포함됩니다
4. 여기에는 `@Presents`로 감싸진 타입도 포함됩니다 (예: `@Presents var destination: Destination.State?`는 `Destination.State`가 `Equatable`이어야 합니다)
5. 이 conformance는 아래로 전파됩니다 - nested된 타입 중 하나라도 `Equatable`로 만들 수 없다면, 부모 `State`는 `TestStore`로 테스트할 수 없습니다

**예시**:
```swift
// ❌ Cannot test - State doesn't conform to Equatable
@ObservableState
struct State {
    var items: [Item] = []
    @Presents var destination: Destination.State?
}

// ✅ Can test - State and all nested types conform to Equatable
@ObservableState
struct State: Equatable {
    var items: [Item] = []  // Item must be Equatable
    @Presents var destination: Destination.State?  // Destination.State must be Equatable
}

// Destination.State must be Equatable
@Reducer enum Destination {
    case settings(SettingsFeature)  // SettingsFeature.State must be Equatable
}
extension Destination.State: Equatable {}

// And any child features used by Destination
@ObservableState
struct SettingsFeature.State: Equatable {
    // All properties must be Equatable
}
```

**State를 Equatable로 만들 수 없는 경우**:
- nested된 타입 중 하나라도 `Equatable`을 준수할 수 없다면, 해당 reducer에는 `TestStore`를 사용할 수 없습니다
- 테스트 가능한 로직을 `Equatable` state를 가진 child reducer로 추출하는 리팩토링을 고려하세요
- 또는 `TestStore` 없이 `Equatable`이 아닌 타입을 별도로 테스트하세요

## 기본 Test Suite

```swift
@Suite("Feature Name")
@MainActor
struct FeatureNameTests {
    typealias Reducer = FeatureNameReducer

    // Test data and helpers
    private let testData = TestData()

    private func makeStore(
        initialState: Reducer.State = .init(),
        dependencies: (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<Reducer> {
        TestStore(initialState: initialState) {
            Reducer()
        } withDependencies: {
            $0.apiClient = .test()
            $0.analytics = .test()
            $0.continuousClock = ImmediateClock()
            $0.notificationFeedbackGenerator = .test()
            $0.dismiss = DismissEffect { }
            dependencies(&$0)
        }
    }
}
```

## 테스트 이름 규칙

```swift
// ✅ Descriptive test names that explain the scenario
@Test("onAppear loads data successfully")
func testOnAppearSuccess() async { }

@Test("handles network error gracefully")
func testNetworkError() async { }

@Test("validates form before submission")
func testFormValidation() async { }

// For complex scenarios, use underscores
@Test("user_can_add_multiple_items_and_save")
func testUserCanAddMultipleItemsAndSave() async { }
```

## Test Store 설정

### 기본 설정

```swift
private func makeStore(
    initialState: Reducer.State = .init(),
    dependencies: (inout DependencyValues) -> Void = { _ in }
) -> TestStoreOf<Reducer> {
    TestStore(initialState: initialState) {
        Reducer()
    } withDependencies: {
        // Default test dependencies
        $0.apiClient = .test()
        $0.analytics = .test()
        $0.continuousClock = ImmediateClock()
        $0.notificationFeedbackGenerator = .test()
        $0.dismiss = DismissEffect { }

        // Custom dependencies
        dependencies(&$0)
    }
}
```

### 사용자 지정 State 설정

```swift
private func makeStore(
    shiftId: Int = 1,
    allowsMultipleSegments: Bool = true
) -> TestStoreOf<EditShiftReducer> {
    let dependencies = ShiftOperationsDependencies(
        allowsMultipleWorkSegments: allowsMultipleSegments,
        allowsConsentOverride: true
    )

    let state = withDependencies {
        $0.shiftOperationsDependencies = dependencies
    } operation: {
        EditShiftReducer.State(shiftId: shiftId)
    }

    return TestStore(initialState: state) {
        EditShiftReducer()
    } withDependencies: {
        $0.shiftClient = .test()
        $0.shiftOperationsDependencies = dependencies
    }
}
```

## Mock Dependency

```swift
extension APIClient {
    static func test(
        fetchData: @escaping () async throws -> [Item] = { [] },
        saveData: @escaping (Item) async throws -> Void = { _ in }
    ) -> Self {
        Self(
            fetchData: fetchData,
            saveData: saveData
        )
    }
}

extension Analytics {
    static func test(
        track: @escaping (Event) -> Void = { _ in }
    ) -> Self {
        Self(track: track)
    }
}
```
