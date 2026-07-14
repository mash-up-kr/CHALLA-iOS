# Strict Concurrency (Swift 6)

Swift 6의 strict concurrency checking은 compile time에 data race를 제거합니다.

## Strict Concurrency 활성화하기

### Package.swift
```swift
.target(
    name: "MyTarget",
    swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
    ]
)
```

### Build Settings (Xcode)
- SWIFT_STRICT_CONCURRENCY = complete

## Strict Mode가 강제하는 것

1. Actor boundary를 넘는 값에 대한 **Sendable conformance**
2. @MainActor와 actor type에 대한 **Isolation checking**
3. async context에서 non-Sendable type의 **암시적 capture 금지**
4. 전역 변수와 함수에 대한 **적절한 annotation**

## Typed Throws (Swift 6.2)

함수가 던지는 정확한 error type을 명시합니다.

### 기본 Typed Throws
```swift
enum ValidationError: Error {
    case tooShort
    case invalidFormat
}

func validate(_ input: String) throws(ValidationError) {
    guard input.count > 5 else {
        throw ValidationError.tooShort
    }
}

// Caller knows exact error type
do {
    try validate("abc")
} catch {
    // error is ValidationError, not any Error
    switch error {
    case .tooShort: print("Too short")
    case .invalidFormat: print("Invalid")
    }
}
```

### Never Throws
```swift
func parseInteger(_ string: String) throws(Never) -> Int {
    // Compiler knows this never throws
    Int(string) ?? 0
}

// No try needed
let value = parseInteger("123")
```

### Generic Throws
```swift
func transform<E: Error>(
    _ value: String,
    using: (String) throws(E) -> Int
) throws(E) -> Int {
    try using(value)
}
```

## Strict Concurrency의 흔한 수정 방법

### 전역 변수
```swift
// ❌ Error: Global mutable state
var sharedCache: [String: Data] = [:]

// ✅ Use actor
actor SharedCache {
    private var cache: [String: Data] = [:]
}

// ✅ Or @MainActor for UI state
@MainActor
var currentTheme: Theme = .light
```

### Non-Sendable을 Capture하는 Closure
```swift
class ViewModel {
    var items: [Item] = []

    func load() {
        // ❌ Error: Capturing non-Sendable self
        Task {
            self.items = await fetch()
        }
    }
}

// ✅ Make ViewModel @MainActor
@MainActor
class ViewModel {
    var items: [Item] = []

    func load() {
        Task {
            self.items = await fetch()
        }
    }
}
```

### Non-Sendable 함수 매개변수
```swift
// ❌ Error: Non-Sendable closure
func runAsync(_ action: () -> Void) async {
    action()
}

// ✅ Require Sendable
func runAsync(_ action: @Sendable () -> Void) async {
    action()
}
```

## Sendable 추론

Swift 6는 다음에 대해 Sendable을 자동으로 추론합니다:
- 모든 저장 property가 Sendable인 struct
- 모든 associated value가 Sendable인 enum
- Actor
- 불변(immutable) Sendable property만 있는 final class

```swift
// Automatically Sendable
struct User {
    let id: String
    let name: String
}

// NOT automatically Sendable (has var)
struct MutableUser {
    var name: String
}
```

## 외부 Type을 위한 @unchecked Sendable

Type이 아직 Sendable하지 않은 외부 package의 type을 포함할 경우, TODO 주석과 함께 `@unchecked Sendable`을 사용하세요:

```swift
@Reducer public struct FeatureTracking {
    public struct Tracker: Sendable {
        // TODO: @unchecked Sendable - Contains LegacyRecord (LegacySDK) and CLLocation (CoreLocation)
        // which are not marked Sendable. Revisit when LegacySDK is modernized to Swift 6.
        public enum Event: Equatable, @unchecked Sendable {
            case operationRequested(
                record: LegacyRecord,    // External type — not Sendable
                location: CLLocation?    // Apple type — not Sendable
            )
            case operationSuccess
            case operationFailure(String)
        }
    }
}
```

### @unchecked Sendable을 사용할 시점

| 상황 | @unchecked Sendable 사용? |
|----------|-------------------------|
| 외부 type이 Sendable하지 않음 (CLLocation 등) | ✅ 사용, TODO와 함께 |
| Apple framework type이 Sendable하지 않음 | ✅ 사용, TODO와 함께 |
| 자체 mutable class | ❌ 사용하지 말고 actor로 만들 것 |
| Immutable reference type | ✅ 진짜로 immutable하다면 사용 |
| `var` property가 있는 type | ❌ 사용하지 말고 actor 또는 재설계 |

### @unchecked가 필요한 흔한 외부 Type

- `CLLocation`, `CLLocationCoordinate2D` (CoreLocation)
- Sendable 여부가 아직 검토되지 않은 legacy Obj-C framework의 type
- Third-party SDK type

### @preconcurrency import 대안

아직 마이그레이션되지 않은 package로부터의 import에는 `@preconcurrency import`를 사용하세요:

```swift
@preconcurrency import LegacySDK  // Suppresses Sendable warnings for LegacyRecord, LegacyUser, etc.
import CoreLocation  // CLLocation still requires @unchecked Sendable
```

전체 module에는 **@preconcurrency를 우선적으로 사용**하세요. Import 방식으로 충분하지 않은 개별 type에는 **@unchecked Sendable**을 사용하세요.

## Migration 전략

1. 한 번에 하나의 module씩 strict concurrency 활성화
2. 전역 mutable state를 먼저 수정 (actor 또는 @MainActor 사용)
3. View model과 UI class에 @MainActor 추가
4. Closure 매개변수에 @Sendable 추가
5. Legacy 의존성에는 @preconcurrency 사용 (modern-attributes.md 참고)
6. 향후 정리를 위해 @unchecked Sendable 사용 부분에 TODO 주석 추가
