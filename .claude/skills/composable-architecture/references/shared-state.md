# Shared State

`@Shared`를 사용해 TCA에서 영구적이고 공유되는 state를 다루는 패턴입니다.

## AppStorage를 사용하는 @Shared

UserDefaults 기반의 영구 state에는 `@Shared(.appStorage)`를 사용하세요.

```swift
@ObservableState
struct State: Equatable {
    @Shared(.appStorage("sortOrder")) var sortOrder: String = "date"
    @Shared(.appStorage("showCompleted")) var showCompleted: Bool = true
}
```

## 스레드에 안전한(Thread-Safe) 변경

@Shared state를 thread-safe하게 변경할 때는 `.withLock`을 사용하세요.

```swift
case .view(.onChangeSortOrder(let order)):
    state.$sortOrder.withLock { $0 = order }
    return .none

case .view(.onToggleCompleted):
    state.$showCompleted.withLock { $0.toggle() }
    return .none
```

## 애니메이션이 적용된 변경

애니메이션이 적용된 변경을 위해 `.withLock`을 `withAnimation`으로 감싸세요.

```swift
case .view(.onChangeTheme(let theme)):
    withAnimation {
        state.$themeRawValue.withLock { $0 = theme.rawValue }
    }
    return .none
```

## Computed Property를 이용한 타입 안전 접근

raw-value 기반 state에 타입 안전하게 접근하려면 computed property를 사용하세요.

```swift
@ObservableState
struct State: Equatable {
    @Shared(.appStorage("themeRawValue")) var themeRawValue: String = "system"

    var selectedTheme: Theme {
        Theme(rawValue: themeRawValue) ?? .system
    }
}
```

## Feature 간 공유되는 State

메모리 내에서 state를 공유하려면 persistence 전략 없이 `@Shared`를 사용하세요.

```swift
@ObservableState
struct State: Equatable {
    @Shared var userSession: UserSession
}
```

state를 공유하려면 동일한 `@Shared` reference를 child feature에 전달하세요.

```swift
case .view(.onShowSettings):
    state.destination = .settings(
        SettingsFeature.State(userSession: state.$userSession)
    )
    return .none
```

## 영구 데이터를 위한 FileStorageKey

공유 state를 JSON으로 디스크에 영구 저장하려면 `FileStorageKey`를 사용하세요.

```swift
// Define the shared key
extension SharedKey where Self == FileStorageKey<IdentifiedArrayOf<SyncUp>>.Default {
    static var syncUps: Self {
        Self[
            .fileStorage(.documentsDirectory.appending(component: "sync-ups.json")),
            default: []
        ]
    }
}

// Use in state
@ObservableState
struct State: Equatable {
    @Shared(.syncUps) var syncUps
}

// Mutate with .withLock
case .view(.didAddSyncUp(let syncUp)):
    state.$syncUps.withLock { $0.append(syncUp) }
    return .none

case .view(.didDeleteSyncUp(let id)):
    state.$syncUps.withLock { $0.remove(id: id) }
    return .none
```

### 사용자 지정 파일 위치

```swift
extension SharedKey where Self == FileStorageKey<AppSettings>.Default {
    static var appSettings: Self {
        Self[
            .fileStorage(.applicationSupportDirectory.appending(component: "settings.json")),
            default: AppSettings()
        ]
    }
}
```

### 요구 사항

- 공유되는 타입은 `Codable`을 준수해야 합니다
- 변경 사항은 자동으로 디스크에 영구 저장됩니다
- 파일 저장은 비동기적으로 동작하며 백그라운드에서 처리됩니다

## 비영구 공유를 위한 InMemoryKey

persistence 없이 feature 간에 state를 공유하려면 `InMemoryKey`를 사용하세요.

```swift
// Define the shared key
extension SharedKey where Self == InMemoryKey<Stats> {
    static var stats: Self {
        inMemory("stats")
    }
}

// Use in state
@ObservableState
struct State: Equatable {
    @Shared(.stats) var stats = Stats()
}

// Mutate with .withLock
case .view(.didIncrement):
    state.$stats.withLock { $0.increment() }
    return .none
```

### InMemoryKey를 사용해야 하는 경우

- 병렬 feature(탭, split view) 간에 state를 공유할 때
- persistence가 필요 없는 임시 state일 때
- isolated in-memory state로 테스트할 때
- 디스크 접근을 피해야 하는 성능이 중요한 state일 때

## Persistence 전략 조합하기

```swift
@ObservableState
struct State: Equatable {
    @Shared(.appStorage("theme")) var theme: String = "system"  // UserDefaults
    @Shared(.syncUps) var syncUps: IdentifiedArrayOf<SyncUp>   // File storage
    @Shared(.stats) var stats = Stats()                         // In-memory
}
```

## Effect와 Static Function 내부에서 @Shared 접근하기

**핵심 패턴:** `@Shared`는 async function이나 effect 내부에 직접 선언할 수 있습니다 — parameter로 전달할 필요가 없습니다.

### ❌ 나쁜 예: @Shared를 Parameter로 전달하기

```swift
// Overly complex - requires capturing state in closure
static func enableFeature(
    featureEnabled: Shared<Bool>,
    itemId: UUID?
) async throws {
    featureEnabled.withLock { $0 = true }
    // ...
}

// Caller must capture state
case .enableTapped:
    return .run { [featureEnabled = state.$featureEnabled] _ in
        try await FeatureHelper.enableFeature(
            featureEnabled: featureEnabled,
            itemId: itemId
        )
    }
```

### ✅ 좋은 예: Function 내부에서 @Shared에 직접 접근하기

```swift
// Cleaner - function is self-contained
static func enableFeature(itemId: UUID?) async throws {
    @Shared(.appStorage("featureEnabled")) var featureEnabled
    $featureEnabled.withLock { $0 = true }
    // ...
}

// Caller is simple
case .enableTapped:
    return .run { _ in
        try await FeatureHelper.enableFeature(itemId: itemId)
    }
```

### 이 방식이 동작하는 이유

- `@Shared` property는 State struct뿐 아니라 어디에나 선언할 수 있습니다
- property wrapper가 공유 state 접근을 자동으로 처리합니다
- function signature를 깔끔하게 유지합니다
- effect closure에서 `state.$property`를 캡처할 필요가 없습니다
