---
name: swift-testing
description: Swift Testing(@Test, #expect, #require)으로 테스트를 작성하거나, XCTest에서 마이그레이션하거나, async 테스트를 구현하거나, 테스트를 매개변수화할 때 사용합니다.
---

# Swift Testing Framework

Swift Testing framework를 사용하는 최신 테스트 방식입니다. XCTest는 없습니다.

## 개요

Swift Testing은 XCTest를 더 간결하고 async 지원이 뛰어나며 기본적으로 테스트를 parallel로 실행하는 최신 macro 기반 접근 방식으로 대체합니다. 핵심 원칙: XCTest를 배웠다면 그것을 잊으십시오—Swift Testing은 다르게 동작합니다.

## 참고 자료

- [Apple 공식 문서](https://developer.apple.com/documentation/testing)
- [마이그레이션 가이드](https://steipete.me/posts/2025/migrating-700-tests-to-swift-testing)

## 핵심 개념

### Assertion

| Macro | 용도 |
|-------|----------|
| `#expect(expression)` | 느슨한 검사 — 실패해도 계속 진행됩니다. 대부분의 assertion에 사용합니다. |
| `#require(expression)` | 엄격한 검사 — 실패 시 테스트가 중단됩니다. 사전 조건에만 사용합니다. |

### Optional 언래핑

```swift
let user = try #require(await fetchUser(id: "123"))
#expect(user.id == "123")
```

## Test 구조

```swift
import Testing
@testable import YourModule

@Suite
struct FeatureTests {
    let sut: FeatureType
    
    init() throws {
        sut = FeatureType()
    }
    
    @Test("Description of behavior")
    func testBehavior() {
        #expect(sut.someProperty == expected)
    }
}
```

## Assertion 변환

| XCTest | Swift Testing |
|--------|---------------|
| `XCTAssert(expr)` | `#expect(expr)` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertNil(a)` | `#expect(a == nil)` |
| `XCTAssertNotNil(a)` | `#expect(a != nil)` |
| `try XCTUnwrap(a)` | `try #require(a)` |
| `XCTAssertThrowsError` | `#expect(throws: ErrorType.self) { }` |
| `XCTAssertNoThrow` | `#expect(throws: Never.self) { }` |

## Error 테스트

```swift
#expect(throws: (any Error).self) { try riskyOperation() }
#expect(throws: NetworkError.self) { try fetch() }
#expect(throws: NetworkError.timeout) { try fetch() }
#expect(throws: Never.self) { try safeOperation() }
```

## Parameterized Test

```swift
@Test("Validates inputs", arguments: zip(
    ["a", "b", "c"],
    [1, 2, 3]
))
func testInputs(input: String, expected: Int) {
    #expect(process(input) == expected)
}
```

**경고:** zip 없이 여러 컬렉션을 사용하면 Cartesian product가 생성됩니다.

## Async 테스트

```swift
@Test func testAsync() async throws {
    let result = try await fetchData()
    #expect(!result.isEmpty)
}
```

### Confirmation

```swift
@Test func testCallback() async {
    await confirmation("callback received") { confirm in
        let sut = SomeType { confirm() }
        sut.triggerCallback()
    }
}
```

## Tag

```swift
extension Tag {
    @Tag static var fast: Self
    @Tag static var networking: Self
}

@Test(.tags(.fast, .networking))
func testNetworkCall() { }
```

## 흔한 함정

1. **`#require` 과도한 사용** — 대부분의 검사에는 `#expect`를 사용
2. **State isolation을 잊음** — 각 테스트는 NEW instance를 받습니다
3. **의도치 않은 Cartesian product** — 짝을 이루는 입력에는 항상 `zip` 사용
4. **`.serialized`를 사용하지 않음** — thread에 안전하지 않은 legacy 테스트에 적용

## 흔한 실수

1. **`#require` 과도한 사용** — `#require`는 사전 조건에만 사용해야 합니다. 일반 assertion에 사용하면 모든 실패를 보고하는 대신 첫 번째 실패에서 테스트가 중단됩니다. assertion에는 `#expect`를 사용하고, 이후 assertion이 해당 값에 의존할 때만 `#require`를 사용하세요.

2. **Cartesian product 버그** — `@Test(arguments: [a, b], [c, d])`는 2개가 아니라 4개의 조합을 생성합니다. argument를 올바르게 짝짓기 위해 항상 `zip`을 사용하세요: `arguments: zip([a, b], [c, d])`.

3. **State isolation을 잊음** — Swift Testing은 테스트 method마다 새로운 테스트 instance를 생성합니다. 하지만 테스트 간 공유 state(정적 변수, singleton)는 여전히 leak됩니다. dependency injection을 사용하거나 테스트 사이에 singleton을 정리하세요.

4. **Parallel 테스트 충돌** — Swift Testing은 기본적으로 테스트를 parallel로 실행합니다. 공유 파일, 데이터베이스, singleton을 다루는 테스트는 서로 간섭합니다. `.serialized` 또는 isolation 전략을 사용하세요.

5. **`async`를 자연스럽게 사용하지 않음** — async 작업을 `Task { }`로 감싸면 목적이 무의미해집니다. 테스트 함수 시그니처에서 `async/await`를 직접 사용하세요: `@Test func testAsync() async throws { }`.

6. **Confirmation 오용** — `confirmation`은 callback이 호출되었는지 검증하기 위한 것입니다. assertion 용도로 사용하는 것은 잘못되었습니다. assertion에는 `#expect`를, callback 횟수에는 `confirmation`을 사용하세요.
