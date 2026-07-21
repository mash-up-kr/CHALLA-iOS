# Swift 6 Concurrency (Swift 6.2+)

고급 pattern: @concurrent, nonisolated(unsafe), actor isolation.

## 점진적 여정: Single-Threaded로 시작하기

> **Apple (WWDC 2025)**: "Start by running all code on the main thread."

```
Single-Threaded → Async/Await → @concurrent → Actors
     ↓               ↓              ↓           ↓
   Start here   Hide latency   Background   Move data
                (network)      CPU work     off main
```

**진행할 시점:** 먼저 프로파일링하세요. 필요할 때만 복잡성을 추가하세요.

## @concurrent Attribute (Swift 6.2+)

함수가 **항상 background thread pool에서 실행**되도록 강제합니다.

```swift
@concurrent
func decodeImage(_ data: Data) async -> Image {
    // Always runs on background — good for image processing, parsing
    return processImageData(data)
}

// Usage — automatically offloads
let image = await decodeImage(data)
```

**요구 사항:** Swift 6.2, Xcode 16.2+, iOS 18.2+

### Main Actor와의 연결 끊기

```swift
@MainActor class ImageModel {
    var cache: [URL: Image] = [:]

    @concurrent
    func decode(_ data: Data, url: URL) async -> Image {
        if let img = cache[url] { return img }  // ❌ Error: main actor access!
        return processImageData(data)
    }
}
```

**해결: 호출자로 접근을 옮길 것** (권장):
```swift
func fetchAndDisplay(url: URL) async throws {
    if let img = cache[url] { view.displayImage(img); return }  // ✅ On main actor
    let data = try await URLSession.shared.data(from: url).0
    let image = await decode(data)  // @concurrent — no cache access needed
    view.displayImage(image)
}
```

## nonisolated vs @concurrent

| Attribute | 실행 위치 | 사용 사례 |
|-----------|---------|----------|
| `nonisolated` | 호출자의 actor | Library API — 호출자가 결정 |
| `@concurrent` | Background pool | 항상 background에서 처리하는 작업 |

## nonisolated(unsafe) 탈출구

접근이 안전하다는 것을 **알고 있지만** compiler가 증명할 수 없을 때 사용하세요.

```swift
class LegacyCache {
    nonisolated(unsafe) var sharedState: [String: Data] = [:]  // ⚠️ Prove safety first
}
```

**먼저 고려할 것:** `actor`로 만들거나, `@MainActor`를 추가하거나, `@unchecked Sendable`을 사용하세요.

### Static Comparator Pattern

Static 정렬 comparator의 경우, `nonisolated(unsafe) static var`보다 `@Sendable` closure를 사용한 `static let`을 선호하세요:

```swift
// ❌ Before: Requires nonisolated(unsafe)
extension SortableItem {
    nonisolated(unsafe) static var dateAscending: (SortableItem, SortableItem) -> Bool = { lhs, rhs in
        lhs.date < rhs.date
    }
}

// ✅ After: Use static let with @Sendable
extension SortableItem {
    static let dateAscending: @Sendable (SortableItem, SortableItem) -> Bool = { lhs, rhs in
        lhs.date < rhs.date
    }

    static let priorityDescending: @Sendable (SortableItem, SortableItem) -> Bool = { lhs, rhs in
        lhs.priority > rhs.priority
    }
}

// Usage — works with standard library sorting
let sorted = items.sorted(by: SortableItem.dateAscending)
```

**이 방법이 동작하는 이유:** `static let` closure는 한 번만 평가되며 immutable합니다. `@Sendable`을 추가하면 mutable state를 capture하지 않는다는 것이 증명됩니다.

## Main Actor 경쟁을 위한 Actor

```swift
// ❌ Problem: Network manager on main actor causes thread hopping
@MainActor class ImageModel {
    let network = NetworkManager()  // Also @MainActor
    func fetch(url: URL) async throws {
        let conn = await network.open(for: url)  // ❌ Hops to main
    }
}
```

```swift
// ✅ Fix: Extract to separate actor
actor NetworkManager {
    private var connections: [URL: Connection] = [:]
    func open(for url: URL) -> Connection {
        connections[url] ?? Connection()
    }
}
```

| 사용 사례 | 해결 방법 |
|----------|----------|
| UI 코드, view model | `@MainActor` class |
| UI가 아닌 subsystem | `actor` |
| 공유 cache/database | `actor` |

## Delegate Value Capture Pattern

`nonisolated` delegate가 `@MainActor` state를 업데이트해야 할 때:

```swift
nonisolated func delegate(_ param: SomeType) {
    let value = param.value  // Step 1: Capture BEFORE Task
    Task { @MainActor in
        self.property = value  // Step 2: Safe on MainActor
    }
}
```

## Isolated Protocol Conformance (Swift 6.2+)

```swift
protocol Exportable { func export() }

// ✅ Conform with explicit isolation
extension PhotoProcessor: @MainActor Exportable {
    func export() { exportAsPNG() }  // Safe: both on MainActor
}
```

## Sendable 전략

| 전략 | 사용 시점 |
|----------|------|
| Value type (struct/enum) | 선호됨 — 항상 |
| `@MainActor` class | UI 관련 class |
| Send 전에 mutation 완료하기 | 수정 후 전달되는 class |
| `@unchecked Sendable` | 최후의 수단 — immutable class에만 |

```swift
// Finish mutations before sending
@concurrent func processImage() async {
    let image = loadImage()
    image.scale(by: 0.5)  // All mutations here
    await view.displayImage(image)  // ✅ Send AFTER done
}
```

## 빠른 결정 트리

```
UI unresponsive?
├─ Network/file I/O? → async/await
├─ CPU work? → @concurrent
└─ Main actor contention? → Extract to actor

"Main actor-isolated accessed from nonisolated"
├─ In delegate? → Value capture pattern
├─ In async? → @MainActor or Task { @MainActor in }
└─ In @concurrent? → Move access to caller
```
