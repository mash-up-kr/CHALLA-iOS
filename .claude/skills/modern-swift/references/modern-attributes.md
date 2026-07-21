# Modern Attributes (Swift 5.9-6.2)

최근 Swift 버전에서 도입된 새로운 attribute입니다.

## @preconcurrency

마이그레이션 중 legacy 코드에 대한 strict concurrency 경고를 억제합니다.

### Import에서
```swift
// Suppress warnings from dependencies not yet updated for Swift 6
@preconcurrency import LegacyNetworking

// Use LegacyNetworking types without Sendable warnings
```

### Protocol에서
```swift
// Allow non-Sendable types to conform during migration
@preconcurrency
protocol DataSource {
    func fetchData() async -> Data
}

// Classes can conform without Sendable requirement
class LocalDataSource: DataSource {
    func fetchData() async -> Data { ... }
}
```

### Type에서
```swift
// Mark type as "will be Sendable eventually"
@preconcurrency
class LegacyManager {
    var state: String = ""
}
```

## @backDeployed

새로운 API 구현을 더 이전 OS 버전에서도 사용할 수 있게 합니다.

```swift
extension String {
    // Available on iOS 13+, but implemented on iOS 17+
    @backDeployed(before: iOS 17)
    @available(iOS 13, *)
    func trimmed() -> String {
        trimmingCharacters(in: .whitespaces)
    }
}

// iOS 13-16: Uses the provided implementation
// iOS 17+: Uses system implementation (if different)
```

### 사용 시점
- Library evolution
- 시스템 API의 back porting
- 점진적인 기능 rollout

## package Access Control (Swift 5.9)

`internal`과 `public` 사이의 새로운 access level입니다.

```swift
// MyLibrary/Sources/Core/User.swift
package struct User {
    package let id: String
    package let name: String
}

// MyLibrary/Sources/Networking/API.swift
package func fetchUser() -> User {
    // Visible within MyLibrary package
}

// App/main.swift
import MyLibrary
// User and fetchUser are NOT visible here
```

### Access Level 요약
```
private < fileprivate < internal < package < public < open
```

| Level | 접근 가능 범위 |
|-------|------------|
| `private` | 현재 선언(declaration) |
| `fileprivate` | 현재 파일 |
| `internal` | 현재 module |
| `package` | 현재 package |
| `public` | Importer (subclass/override 불가) |
| `open` | Importer (subclass/override 가능) |

## @available(*, noasync)

특정 API의 async 사용을 방지합니다.

```swift
@available(*, noasync)
func dangerousBlockingOperation() {
    // Blocks thread - don't call from async context
    Thread.sleep(forTimeInterval: 5)
}

// ❌ Compile error in async context
async {
    dangerousBlockingOperation()
}
```

### 사용 사례
- Blocking I/O 표시
- Deadlock 방지
- Legacy 동기(synchronous) API

## @_exported (Underscore Attribute)

Module의 public API를 재노출(re-export)합니다.

```swift
// In your module
@_exported import Foundation

// Users importing your module get Foundation too
import MyModule
// Can use Foundation types without separate import
```

**경고**: `@_exported`는 underscore가 붙어 있으므로 = 안정적인 API가 아닙니다. 신중하게 사용하세요.

## Macro Attribute

[macros.md](macros.md)를 참고하세요:
- `@attached(member)`
- `@attached(peer)`
- `@attached(accessor)`
- `@attached(memberAttribute)`
- `@attached(conformance)`
- `@freestanding(expression)`

## Migration Pattern

### Swift 5.x에서 Swift 6로
```swift
// 1. Add @preconcurrency to imports
@preconcurrency import LegacySDK

// 2. Use package for internal APIs
package func helperMethod() { }

// 3. Mark blocking code
@available(*, noasync)
func blockingWork() { }
```

### Library Evolution
```swift
// Backport new features
@backDeployed(before: iOS 18)
@available(iOS 15, *)
func modernFeature() { }
```
