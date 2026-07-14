# Task Cancellation

Swift 6.2 structured concurrency에서의 협력적(cooperative) cancellation pattern입니다.

## 협력적(Cooperative) 모델

Swift task는 **협력적 cancellation**을 사용합니다:
- Cancellation은 강제되지 않고 요청됩니다
- Task는 cancellation을 확인하고 응답해야 합니다
- 자동으로 중단되지 않습니다

## checkCancellation vs isCancelled

### Task.checkCancellation()
Cancel되면 `CancellationError`를 던집니다. Throwing context에서 사용하세요.

```swift
func processItems(_ items: [Item]) async throws {
    for item in items {
        try Task.checkCancellation()
        await process(item)
    }
}
```

### Task.isCancelled
`Bool`을 반환합니다. Throwing이 아닌 context에서 우아한 정리를 위해 사용하세요.

```swift
func processItems(_ items: [Item]) async {
    for item in items {
        if Task.isCancelled {
            print("Cancelled, stopping early")
            return
        }
        await process(item)
    }
}
```

## withTaskCancellationHandler

Task가 취소될 때 정리 작업을 실행합니다.

```swift
func downloadFile(url: URL) async throws -> Data {
    let download = URLSession.shared.dataTask(with: url)

    return try await withTaskCancellationHandler {
        try await download.value
    } onCancel: {
        download.cancel()
    }
}
```

## Cancellation Pattern

### 장시간 실행되는 루프
```swift
func monitorEvents() async throws {
    while !Task.isCancelled {
        let event = try await fetchNextEvent()
        try Task.checkCancellation()
        await handle(event)
    }
}
```

### Cancellation이 있는 TaskGroup
```swift
func fetchWithTimeout(ids: [String]) async throws -> [User] {
    try await withThrowingTaskGroup(of: User.self) { group in
        // Add tasks
        for id in ids {
            group.addTask {
                try await fetchUser(id: id)
            }
        }

        // Cancel all if one fails
        var users: [User] = []
        do {
            for try await user in group {
                users.append(user)
            }
        } catch {
            group.cancelAll()
            throw error
        }
        return users
    }
}
```

### Timeout Pattern
```swift
func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError()
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
```

## Best Practice

1. 루프와 장시간 작업에서 **자주 확인**하기
2. Child task로 **cancellation을 전파**하기
3. Cancellation handler에서 **리소스 정리**하기
4. Cancellation을 **무시하지 말고** 적절히 대응하기
5. 더 깔끔한 error 처리를 위해 throwing 코드에서 **checkCancellation() 사용**하기
