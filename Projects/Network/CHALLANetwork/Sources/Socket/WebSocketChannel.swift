import Foundation
import os

/// WebSocket 한 개를 여닫고 메시지를 주고받는 실행기의 추상.
///
/// `STOMPClient`는 이 프로토콜에만 의존하고, 테스트는 `FakeWebSocketChannel`을 꽂는다.
/// `URLSessionWebSocketTask`와 그 `Message`가 격리 경계를 넘지 않도록 자체 타입으로 감싼다.
protocol WebSocketChannel: Sendable {

    /// 핸드셰이크를 시작한다. 거절(401 등)은 여기서 알 수 없고 첫 `receive()`에서 드러난다.
    func open(_ request: URLRequest) async

    func send(_ frame: WebSocketFrame) async throws

    /// 메시지 한 개를 기다린다. 연결이 끊기면 오류를 던진다.
    func receive() async throws -> WebSocketFrame

    /// 연결이 살아 있는지 확인한다. 끊겨 있으면 오류를 던진다.
    ///
    /// `receive()`만으로는 끊김을 알 수 없다 — 상대가 사라져도 `receive()`는 그대로 매달려 있다.
    /// 양쪽 다 조용한 구간(서버가 STOMP 하트비트를 거절한 경우)에는 이것이 유일한 감지 수단이다.
    func ping() async throws

    /// 실패한 업그레이드의 HTTP 상태 코드. delegate 없이 401을 판별하는 경로다.
    func handshakeStatusCode() async -> Int?

    func close() async
}

/// WebSocket 메시지. STOMP는 텍스트만 쓰지만 서버가 바이너리를 보낼 수 있어 둘 다 받는다.
enum WebSocketFrame: Sendable, Equatable {
    case text(String)
    case data(Data)

    /// STOMP 파서에 넘길 바이트. 텍스트든 바이너리든 같은 코덱을 탄다.
    var payload: Data {
        switch self {
        case let .text(text): Data(text.utf8)
        case let .data(data): data
        }
    }
}

/// `URLSessionWebSocketTask` 기반 구현.
///
/// delegate를 두지 않는다 — delegate는 `invalidateAndCancel()` 전까지 세션이 붙들고 있어서,
/// 프로세스 수명 내내 사는 이 객체에서는 누수가 된다. 핸드셰이크 실패 상태 코드는 `task.response`로 읽는다.
actor URLSessionWebSocketChannel: WebSocketChannel {

    private let session: URLSession
    private var task: URLSessionWebSocketTask?

    init() {
        let configuration = URLSessionConfiguration.default
        // 핸드셰이크에만 걸리는 값이다. 연결된 뒤의 대기(receive)에는 적용되지 않는다.
        configuration.timeoutIntervalForRequest = Const.handshakeTimeout
        session = URLSession(configuration: configuration)
    }

    func open(_ request: URLRequest) {
        let task = session.webSocketTask(with: request)
        self.task = task
        task.resume()
    }

    func send(_ frame: WebSocketFrame) async throws {
        guard let task else { throw STOMPError.notConnected }
        try await task.send(frame.message)
    }

    func receive() async throws -> WebSocketFrame {
        guard let task else { throw STOMPError.notConnected }
        return try await WebSocketFrame(task.receive())
    }

    func ping() async throws {
        guard let task else { throw STOMPError.notConnected }
        // `sendPing`의 핸들러는 1회 호출이 보장되지 않는다 — ping이 미결인 채로 task가 닫히면
        // pong으로 이미 불린 핸들러가 종료 정리 경로에서 에러와 함께 한 번 더 불린다.
        // 두 번째 호출을 버리지 않으면 continuation 이중 resume으로 프로세스가 죽는다.
        // 핸들러는 액터 밖(URLSession의 델리게이트 큐)에서 불려서 락으로 막는다.
        let hasResumed = OSAllocatedUnfairLock(initialState: false)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            task.sendPing { error in
                let alreadyResumed = hasResumed.withLock { resumed in
                    defer { resumed = true }
                    return resumed
                }
                guard !alreadyResumed else { return }
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func handshakeStatusCode() -> Int? {
        (task?.response as? HTTPURLResponse)?.statusCode
    }

    func close() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }

    private enum Const {
        static let handshakeTimeout: TimeInterval = 15
    }
}

private extension WebSocketFrame {

    var message: URLSessionWebSocketTask.Message {
        switch self {
        case let .text(text): .string(text)
        case let .data(data): .data(data)
        }
    }

    init(_ message: URLSessionWebSocketTask.Message) throws {
        switch message {
        case let .string(text): self = .text(text)
        case let .data(data): self = .data(data)
        @unknown default:
            throw STOMPError.malformedFrame(reason: "알 수 없는 WebSocket 메시지 종류입니다.")
        }
    }
}
