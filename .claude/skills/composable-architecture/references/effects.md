# Effects

TCA reducer에서 side effect를 처리하기 위한 패턴입니다.

## 기본 Effect

### async 작업을 위한 .run

```swift
case .loadData:
    state.isLoading = true
    return .run { send in
        let data = try await apiClient.fetchData()
        await send(.didLoadData(.success(data)))
    }

case .didLoadData(.success(let data)):
    state.isLoading = false
    state.data = data
    return .none
```

### 동기적인 action dispatch를 위한 .send

```swift
case .view(.onTapSave):
    return .send(.saveData)
```

## Effect Error Handling

구조화된 error handling을 위해 `catch:` parameter를 사용하세요.

```swift
case .loadItem(let id):
    return .run { send in
        let item = try await apiClient.fetchItem(id)
        await send(.itemLoaded(item))
    } catch: { error, send in
        await send(.loadFailed(error))
    }
```

사용자에게 노출하지 않고 로그만 남기고 싶은 중요하지 않은 error의 경우:

```swift
case .syncData:
    return .run { send in
        try await syncClient.sync()
        await send(.syncCompleted)
    } catch: { error, _ in
        reportIssue(error)
    }
```

## Effect Composition

### 순차적인 effect를 위한 .concatenate

```swift
case .onAppear:
    return .concatenate(
        .send(.loadData),
        .send(.trackAnalytics)
    )
```

### 동시 effect를 위한 .merge

```swift
case .onSave:
    return .merge(
        .send(.delegate(.didSave)),
        .run { _ in await dismiss() }
    )
```

## Cancellation

### 오래 실행되는 effect를 위한 .cancellable

```swift
case .startStreaming:
    return .run { send in
        for try await data in client.stream() {
            await send(.didReceiveData(data))
        }
    }
    .cancellable(id: "data-stream", cancelInFlight: true)

case .stopStreaming:
    return .cancel(id: "data-stream")
```

## View Lifecycle Effect

view의 lifetime 동안 실행되어야 하는 effect에는 `.finish()`와 함께 `.runTasks`를 사용하세요.

```swift
// In Reducer
@CasePathable
enum View {
    case runTasks
    case onAppear
}

case .view(.runTasks):
    return .run { send in
        for await status in statusClient.stream() {
            await send(.statusChanged(status))
        }
    }
    // No .cancellable() needed - .task handles auto-cancellation

case .view(.onAppear):
    return .run { send in
        let data = try await loadInitialData()
        await send(.dataLoaded(data))
    }
```

```swift
// In View
var body: some View {
    List { /* ... */ }
        .task {
            await send(.runTasks).finish()  // Keeps alive until view disappears
        }
        .onAppear {
            send(.onAppear)  // Immediate one-time work
        }
}
```

**`.runTasks`를 사용해야 하는 경우:**
- streaming effect (상태 monitor, 실시간 업데이트)
- view의 전체 lifetime 동안 실행되어야 하는 effect
- `.onAppear` + `.onDisappear` + `.cancellable()` 패턴을 대체함

## Timer Effect

### Clock Dependency를 사용한 기본 Timer

```swift
@Dependency(\.continuousClock) var clock
private enum CancelID { case timer }

case .toggleTimerButtonTapped:
    state.isTimerActive.toggle()
    return .run { [isTimerActive = state.isTimerActive] send in
        guard isTimerActive else { return }
        for await _ in self.clock.timer(interval: .seconds(1)) {
            await send(.timerTick)
        }
    }
    .cancellable(id: CancelID.timer, cancelInFlight: true)

case .timerTick:
    state.secondsElapsed += 1
    return .none
```

### 애니메이션이 적용된 Timer 업데이트

```swift
case .toggleTimerButtonTapped:
    state.isTimerActive.toggle()
    return .run { [isTimerActive = state.isTimerActive] send in
        guard isTimerActive else { return }
        for await _ in self.clock.timer(interval: .seconds(1)) {
            await send(.timerTick, animation: .default)
        }
    }
    .cancellable(id: CancelID.timer, cancelInFlight: true)
```

### Duration과 완료 처리가 있는 Timer

```swift
case .startCountdown:
    state.timeRemaining = 60
    return .run { send in
        for await _ in self.clock.timer(interval: .seconds(1)) {
            await send(.timerTick)
        }
    }
    .cancellable(id: CancelID.timer)

case .timerTick:
    state.timeRemaining -= 1
    if state.timeRemaining <= 0 {
        return .concatenate(
            .cancel(id: CancelID.timer),
            .send(.timerCompleted)
        )
    }
    return .none
```

## Effect에서 State 캡처하기

### Async 작업을 위한 캡처

```swift
case .numberFactButtonTapped:
    state.isLoading = true
    return .run { [count = state.count] send in
        let fact = try await factClient.fetch(count)
        await send(.numberFactResponse(.success(fact)))
    }
```

### 여러 값 캡처하기

```swift
case .searchTextChanged(let text):
    state.searchText = text
    return .run { [text, filter = state.filter, sortOrder = state.sortOrder] send in
        try await Task.sleep(for: .milliseconds(300))
        let results = try await searchClient.search(
            text: text,
            filter: filter,
            sortOrder: sortOrder
        )
        await send(.searchResults(results))
    }
    .cancellable(id: CancelID.search, cancelInFlight: true)
```

### 조건문을 위한 캡처

```swift
case .loadData:
    return .run { [isOfflineMode = state.isOfflineMode] send in
        if isOfflineMode {
            let data = await cacheClient.loadFromCache()
            await send(.dataLoaded(data))
        } else {
            let data = try await apiClient.fetchData()
            await send(.dataLoaded(data))
        }
    }
```
