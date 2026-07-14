# Macros (Swift 5.9+)

Swift macro는 compile-time 코드 생성과 변환을 가능하게 합니다.

## 두 가지 유형의 Macro

### Freestanding Macro
`#`로 시작하며, 호출 지점에서 코드로 확장됩니다.

```swift
// Usage
let url = #URL("https://example.com")

// Expands to compile-time validated URL
```

### Attached Macro
`@`로 시작하며, 선언(declaration)을 수정하거나 추가합니다.

```swift
// Usage
@OptionSet
struct Permission {
    private enum Options: Int {
        case read = 1
        case write = 2
        case delete = 4
    }
}

// Expands to add conformance, properties, initializers
```

## 흔한 Freestanding Macro

### #URL
```swift
// Compile-time URL validation
let api = #URL("https://api.example.com/users")
// Error if URL is invalid
```

### #selector, #keyPath
```swift
// Type-safe selectors (UIKit)
button.addTarget(self, action: #selector(handleTap), for: .touchUpInside)

// Type-safe key paths
let name = user[keyPath: #keyPath(User.name)]
```

## 흔한 Attached Macro

### @OptionSet
Option set을 위한 RawRepresentable conformance를 생성합니다.

```swift
@OptionSet<UInt8>
struct ShippingOptions {
    private enum Options: Int {
        case nextDay
        case priority
        case gift
    }
}

// Generated: init, contains, insert, remove, etc.
let options: ShippingOptions = [.nextDay, .gift]
```

### @Observable (SwiftUI)
SwiftUI를 위한 observation 인프라를 생성합니다.

```swift
@Observable
class ViewModel {
    var count = 0
}

// No need for @Published or ObservableObject
```

## Macro의 Role

Macro는 무엇을 할 수 있는지를 결정하는 특정 role로 정의됩니다:

| Role | 하는 일 | 예시 |
|------|--------------|---------|
| `@freestanding(expression)` | expression으로 확장 | `#URL` |
| `@attached(member)` | type에 member 추가 | `@Observable` |
| `@attached(peer)` | peer 선언 추가 | `@Test`가 async variant 생성 |
| `@attached(accessor)` | getter/setter 추가 | `@Observable` property wrapper |
| `@attached(memberAttribute)` | member에 attribute 추가 | 모든 member에 `@MainActor` 적용 |
| `@attached(conformance)` | protocol conformance 추가 | `@OptionSet`이 `OptionSet` 추가 |

## Macro를 사용할 때

### ✅ 좋은 사용 사례
- Boilerplate 제거 (OptionSet, Observable)
- Compile-time validation (#URL, #require)
- 선언으로부터의 코드 생성
- Type-safe wrapper

### ❌ 피해야 할 경우
- Runtime 로직 (함수를 사용할 것)
- 단순한 코드 재사용 (함수/protocol을 사용할 것)
- 복잡한 변환 (디버깅이 어려움)
- protocol/generic으로 달성 가능한 모든 것

## Macro Expansion

Macro는 compile time에 확장됩니다. Xcode에서 expansion을 확인하려면:
- Macro 사용 부분을 마우스 우클릭
- "Expand Macro"로 생성된 코드 확인

```swift
@OptionSet
struct Permissions {
    private enum Options: Int {
        case read, write
    }
}

// Expand to see:
// - OptionSet conformance
// - Static properties
// - Initializers
// - Insert/remove methods
```

## Macro 만들기 (개괄)

Macro는 별도의 Swift package입니다:

1. Package에서 macro의 signature를 **정의**
2. Macro target에서 SwiftSyntax를 사용해 **구현**
3. Expansion을 **테스트**
4. 코드에서 **사용**

이는 고급 주제이며 대부분의 개발자는 macro를 만들지 않고 **사용**만 합니다.

## 핵심 원칙

1. **추가 전용(Additive only)** - Macro는 코드를 제거할 수 없음
2. **결정론적(Deterministic)** - 동일한 입력 = 동일한 출력
3. **샌드박스화(Sandboxed)** - 파일 시스템, 네트워크 등 접근 불가
4. **검사 가능(Inspectable)** - 항상 "Expand Macro"로 확인 가능
