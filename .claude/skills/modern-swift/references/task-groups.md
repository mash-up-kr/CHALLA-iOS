# Task Groups & Structured Concurrency

Swift 6.2에서 TaskGroup과 async-let을 사용한 병렬 실행 pattern입니다.

## TaskGroup — Structured Concurrency

### ✅ 현대적 Pattern
```swift
func fetchAllUsers(ids: [String]) async throws -> [User] {
    try await withThrowingTaskGroup(of: User.self) { group in
        for id in ids {
            group.addTask {
                try await fetchUser(id: id)
            }
        }

        var users: [User] = []
        for try await user in group {
            users.append(user)
        }
        return users
    }
}
```

### ❌ 지원 중단된 Pattern
```swift
// NEVER use DispatchGroup
let group = DispatchGroup()
var users: [User] = []

for id in ids {
    group.enter()
    fetchUserOldStyle(id: id) { user in
        users.append(user)
        group.leave()
    }
}
```

## async-let — 고정된 개수의 병렬 Task

Compile time에 병렬 작업의 정확한 개수를 알고 있을 때 사용하세요.

```swift
func loadDashboard() async throws -> Dashboard {
    async let user = fetchUser()
    async let posts = fetchPosts()
    async let stats = fetchStats()

    return try await Dashboard(
        user: user,
        posts: posts,
        stats: stats
    )
}
```

## TaskGroup Pattern

### 순서대로 결과 수집하기
```swift
func fetchInOrder(ids: [String]) async throws -> [User] {
    try await withThrowingTaskGroup(of: (Int, User).self) { group in
        for (index, id) in ids.enumerated() {
            group.addTask {
                (index, try await fetchUser(id: id))
            }
        }

        var results = [(Int, User)]()
        for try await result in group {
            results.append(result)
        }

        return results.sorted { $0.0 < $1.0 }.map(\.1)
    }
}
```

### 제한된 병렬성
```swift
func processBatch(_ items: [Item]) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        var iterator = items.makeIterator()

        // Start initial batch of 5
        for _ in 0..<5 {
            if let item = iterator.next() {
                group.addTask { try await process(item) }
            }
        }

        // As tasks complete, start new ones
        while let item = iterator.next() {
            try await group.next()
            group.addTask { try await process(item) }
        }

        try await group.waitForAll()
    }
}
```

### Error 발생 시 조기 종료
```swift
func fetchUntilError(ids: [String]) async throws -> [User] {
    try await withThrowingTaskGroup(of: User.self) { group in
        for id in ids {
            group.addTask { try await fetchUser(id: id) }
        }

        var users: [User] = []
        // First error throws and cancels remaining tasks
        for try await user in group {
            users.append(user)
        }
        return users
    }
}
```
