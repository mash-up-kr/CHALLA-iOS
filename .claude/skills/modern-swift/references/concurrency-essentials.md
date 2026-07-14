# Concurrency Essentials

Swift 6.2에서 async/await, @MainActor, actor, Sendable을 위한 핵심 pattern입니다.

## 먼저 Single-Threaded로 시작하기

> **Apple 가이드 (WWDC 2025)**: "Start by running all code on the main thread."

**복잡성을 추가할 시점:**
1. UI가 반응성이 좋다면 (프레임당 <16ms) **single-threaded를 유지**
2. network/file I/O가 UI를 막을 때 **async/await를 추가**
3. CPU 작업이 UI를 멈추게 할 때 **concurrency를 추가** (먼저 프로파일링할 것!)
4. main actor 경쟁이 병목이 될 때 **actor를 추가**

Concurrent 코드는 더 복잡합니다. 프로파일링으로 필요성이 입증되었을 때만 도입하세요.

## Async/Await — Completion Handler가 아님

### ✅ 현대적 Pattern
```swift
func fetchUser(id: String) async throws -> User {
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}

// Calling async functions
Task {
    let user = try await fetchUser(id: "123")
}
```

### ❌ 지원 중단된 Pattern
```swift
// NEVER use completion handlers
func fetchUser(id: String, completion: @escaping (Result<User, Error>) -> Void) {
    URLSession.shared.dataTask(with: url) { data, _, error in
        // ...
    }.resume()
}
```

## @MainActor — DispatchQueue.main이 아님

### ✅ 현대적 Pattern
```swift
@MainActor
class ViewModel: ObservableObject {
    var items: [Item] = []

    func loadItems() async {
        // Already on main actor — UI updates are safe
        items = try await fetchItems()
    }
}

// Or for individual properties
class Service {
    @MainActor var uiState: UIState = .idle
}
```

### ❌ 지원 중단된 Pattern
```swift
// NEVER use DispatchQueue.main.async
DispatchQueue.main.async {
    self.items = newItems
}
```

## Actor Isolation — Lock이 아님

### ✅ 현대적 Pattern
```swift
actor DatabaseManager {
    private var cache: [String: Data] = [:]

    func getData(key: String) -> Data? {
        cache[key]
    }

    func setData(_ data: Data, key: String) {
        cache[key] = data
    }
}

// Usage
let data = await database.getData(key: "user")
```

### ❌ 지원 중단된 Pattern
```swift
// NEVER use locks or serial queues
class DatabaseManager {
    private let queue = DispatchQueue(label: "db")
    private var cache: [String: Data] = [:]

    func getData(key: String) -> Data? {
        queue.sync { cache[key] }
    }
}
```

## Sendable — Thread-Safe Type

### ✅ Sendable 준수
```swift
// Value types are implicitly Sendable
struct User: Sendable {
    let id: String
    let name: String
}

// Actors are implicitly Sendable
actor UserCache { }

// Classes require @unchecked Sendable (use sparingly)
final class ImmutableConfig: @unchecked Sendable {
    let apiKey: String
    let baseURL: URL

    init(apiKey: String, baseURL: URL) {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
}
```

### ❌ 흔한 오류
```swift
// ERROR: Non-Sendable type crossing actor boundary
class MutableState { var count = 0 }

actor Counter {
    // ❌ MutableState is not Sendable
    func update(state: MutableState) { }
}
```

## 흔한 Pattern

### Network Request
```swift
func loadData() async throws -> Data {
    try await URLSession.shared.data(from: url).0
}
```

### Background Work + UI Update
```swift
@MainActor
func refresh() async {
    let data = await Task.detached {
        // Heavy computation off main actor
        await processData()
    }.value

    // Back on main actor automatically
    self.items = data
}
```
