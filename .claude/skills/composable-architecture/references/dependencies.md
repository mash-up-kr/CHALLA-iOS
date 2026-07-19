# Dependencies

TCA에서 dependency injection을 위한 패턴입니다.

## @DependencyClient Macro

`@DependencyClient`를 사용해 자동 test value 생성 기능이 있는 dependency client를 선언하세요.

### Swift 6 Strict Concurrency를 위한 이점

`@DependencyClient`는 Swift 6에서 `nonisolated(unsafe)`가 필요한 수동 `unimplemented` static property의 필요성을 없애줍니다.

```swift
// ❌ Before: Manual unimplemented pattern (requires workaround)
struct LegacyClient: Sendable {
    var fetchData: @Sendable () async throws -> Data

    // nonisolated(unsafe) required in Swift 6 — fragile
    nonisolated(unsafe) static var unimplemented = LegacyClient(
        fetchData: { fatalError("unimplemented") }
    )
}

// ✅ After: @DependencyClient handles it automatically
@DependencyClient
struct ModernClient: Sendable {
    var fetchData: @Sendable () async throws -> Data
}
// testValue auto-generated, no nonisolated(unsafe) needed
```

### 기본 예제

```swift
@DependencyClient
struct APIClient: Sendable {
    var fetchItems: @Sendable () async throws -> [Item]
    var saveItem: @Sendable (Item) async throws -> Void
    var deleteItem: @Sendable (UUID) async throws -> Void
}

extension APIClient: DependencyKey {
    static let liveValue = APIClient(
        fetchItems: {
            let (data, _) = try await URLSession.shared.data(from: itemsURL)
            return try JSONDecoder().decode([Item].self, from: data)
        },
        saveItem: { item in
            var request = URLRequest(url: itemsURL)
            request.httpMethod = "POST"
            request.httpBody = try JSONEncoder().encode(item)
            _ = try await URLSession.shared.data(for: request)
        },
        deleteItem: { id in
            var request = URLRequest(url: itemsURL.appending(path: id.uuidString))
            request.httpMethod = "DELETE"
            _ = try await URLSession.shared.data(for: request)
        }
    )
}

extension DependencyValues {
    var apiClient: APIClient {
        get { self[APIClient.self] }
        set { self[APIClient.self] = newValue }
    }
}
```

> ⚠️ **CHALLA 적용 시 주의**: 위는 TCA 공식 문서의 범용 예제다. 이 저장소에서는 `liveValue`에서 `URLSession`을 직접 호출하지 않는다 — 네트워크는 `CHALLANetwork`를 거치고, `liveValue`/`testValue`/`previewValue` 등록은 Feature 모듈이 아니라 **DIContainer 폴더**에서 한다 (`.claude/rules/architecture.md` 규칙 2).

`@DependencyClient` macro는 `unimplemented` error를 던지는 `.testValue`를 자동으로 생성하여 테스트되지 않은 code path를 잡아냅니다.

### Typed Error를 위한 WrappedError 패턴

dependency client가 `Equatable` conformance를 가진 typed error가 필요할 때, `Swift.Error`를 감싸세요.

```swift
@DependencyClient
struct DataClient: Sendable {
    enum Error: Swift.Error, Equatable, CustomDebugStringConvertible, Sendable {
        struct WrappedError: Swift.Error, Equatable, Sendable {
            let error: Swift.Error
            var localizedDescription: String { error.localizedDescription }
            static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.localizedDescription == rhs.localizedDescription
            }
        }

        case networkError(WrappedError)
        case decodingError(WrappedError)

        var debugDescription: String {
            switch self {
            case .networkError(let e): return "Network: \(e.localizedDescription)"
            case .decodingError(let e): return "Decoding: \(e.localizedDescription)"
            }
        }
    }

    var fetchData: @Sendable () async throws(Error) -> Data
}
```

**참고:** `Swift.Error`는 암묵적으로 `Sendable`이므로, `WrappedError`는 `@unchecked Sendable`이 아니라 그냥 `Sendable`을 사용합니다.

## Reducer에서 Dependency 사용하기

```swift
@Reducer struct FeatureName {
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.analytics) var analytics
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.continuousClock) var clock
}
```

## Test Dependency

`withDependencies`를 사용해 테스트에서 dependency를 override하세요.

```swift
let store = TestStore(initialState: .init()) {
    FeatureReducer()
} withDependencies: {
    $0.apiClient.fetchItems = { [Item(id: 1, name: "Test")] }
    $0.analytics.track = { _ in }
    $0.dismiss = DismissEffect { }
    $0.continuousClock = ImmediateClock()
}
```

## Streaming Dependency

streaming 결과를 제공하는 dependency에는 `AsyncThrowingStream`을 사용하세요.

```swift
@DependencyClient
struct SpeechClient: Sendable {
    var authorizationStatus: @Sendable () -> AuthorizationStatus = { .denied }
    var requestAuthorization: @Sendable () async -> AuthorizationStatus = { .denied }
    var startTask: @Sendable (_ request: SpeechRequest) async
        -> AsyncThrowingStream<SpeechRecognitionResult, Error> = { _ in .finished() }
}

extension SpeechClient: DependencyKey {
    static let liveValue = SpeechClient(
        authorizationStatus: {
            SFSpeechRecognizer.authorizationStatus()
        },
        requestAuthorization: {
            await SFSpeechRecognizer.requestAuthorization()
        },
        startTask: { request in
            AsyncThrowingStream { continuation in
                let recognizer = SFSpeechRecognizer()
                let task = recognizer?.recognitionTask(with: request) { result, error in
                    if let result {
                        continuation.yield(result)
                    }
                    if let error {
                        continuation.finish(throwing: error)
                    }
                    if result?.isFinal == true {
                        continuation.finish()
                    }
                }
                continuation.onTermination = { _ in
                    task?.cancel()
                }
            }
        }
    )
}
```

reducer에서 streaming dependency 사용하기:

```swift
case .startRecording:
    return .run { send in
        let request = createSpeechRequest()
        for try await result in await speechClient.startTask(request) {
            await send(.speechResult(result))
        }
    }
    .cancellable(id: CancelID.speech)
```

## Preview Value

SwiftUI preview에서 사용하는 dependency에 `previewValue`를 정의하세요.

```swift
extension AudioRecorderClient: TestDependencyKey {
    static let previewValue = AudioRecorderClient(
        currentTime: { 10.0 },
        requestRecordPermission: { true },
        startRecording: { _ in true },
        stopRecording: { }
    )

    static let testValue = AudioRecorderClient()  // Unimplemented by default
}
```

preview에서 사용하기:

```swift
#Preview {
    FeatureView(
        store: Store(initialState: Feature.State()) {
            Feature()
        } withDependencies: {
            $0.audioRecorder = .previewValue
        }
    )
}
```

### Test Value vs Preview Value

- **`testValue`**: `@DependencyClient`에 의해 자동 생성되며, `unimplemented` error를 던짐
    - 의도치 않은 dependency 사용을 잡아내기 위해 테스트에서 사용
    - 테스트에서 dependency의 명시적인 mocking을 강제함

- **`previewValue`**: SwiftUI preview를 위한 커스텀 구현
    - preview를 위한 현실적인 mock data를 제공
    - side effect 없이 즉시 반환해야 함
    - static/하드코딩된 값을 사용할 수 있음

```swift
@DependencyClient
struct DataClient: Sendable {
    var fetchData: @Sendable () async throws -> [Item]
}

extension DataClient: TestDependencyKey {
    static let liveValue = DataClient(
        fetchData: {
            // Real network call
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode([Item].self, from: data)
        }
    )

    static let previewValue = DataClient(
        fetchData: {
            // Mock data for previews
            [
                Item(id: 1, name: "Preview Item 1"),
                Item(id: 2, name: "Preview Item 2")
            ]
        }
    )

    // testValue is auto-generated by @DependencyClient
}
```
