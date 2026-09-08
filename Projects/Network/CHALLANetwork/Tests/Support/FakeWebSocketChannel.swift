@testable import CHALLANetwork
import Foundation
import os

/// 테스트가 서버 대신 프레임을 밀어 넣는 채널.
///
/// `push`가 `receive()`보다 먼저 오면 큐에 쌓이고, 늦게 오면 기다리던 `receive()`를 깨운다.
/// 보낸 프레임은 전부 기록해 두어 CONNECT·SUBSCRIBE·UNSUBSCRIBE가 몇 번 나갔는지 검증할 수 있다.
actor FakeWebSocketChannel: WebSocketChannel {

    private(set) var openedRequests: [URLRequest] = []
    private(set) var sentFrames: [WebSocketFrame] = []
    private(set) var closeCount = 0
    private(set) var pingCount = 0
    private var pingFails = false

    /// CONNECT에는 CONNECTED로, SUBSCRIBE에는 그 receipt-id를 단 RECEIPT로 자동 응답한다.
    /// 끄면 테스트가 응답 시점을 직접 잡을 수 있다.
    private let autoRespond: Bool
    private let stubbedStatusCode: Int?

    /// 이 프레임의 전송을 실패시킬지 묻는다. 재구독 전송이 깨졌을 때의 동작을 볼 때 쓴다.
    private let shouldFailSend: @Sendable (STOMPFrame) -> Bool

    private var queued: [Result<WebSocketFrame, any Error>] = []
    private var waiter: CheckedContinuation<WebSocketFrame, any Error>?

    init(
        autoRespond: Bool = false,
        handshakeStatusCode: Int? = nil,
        initialFailure: (any Error)? = nil,
        shouldFailSend: @escaping @Sendable (STOMPFrame) -> Bool = { _ in false }
    ) {
        self.autoRespond = autoRespond
        stubbedStatusCode = handshakeStatusCode
        self.shouldFailSend = shouldFailSend
        // 업그레이드부터 실패하는 채널. 첫 receive()가 곧바로 이 오류로 깨진다.
        if let initialFailure {
            queued.append(.failure(initialFailure))
        }
    }

    // MARK: - WebSocketChannel

    func open(_ request: URLRequest) {
        openedRequests.append(request)
    }

    func send(_ frame: WebSocketFrame) throws {
        // 실패한 전송도 기록한다 — 몇 번 시도했는지가 검증 대상이다.
        sentFrames.append(frame)
        let decoded = STOMPCodec.decode(frame.payload).frames
        if decoded.contains(where: shouldFailSend) {
            throw STOMPError.notConnected
        }
        guard autoRespond else { return }
        respond(to: frame)
    }

    func receive() async throws -> WebSocketFrame {
        if !queued.isEmpty {
            return try queued.removeFirst().get()
        }
        return try await withCheckedThrowingContinuation { continuation in
            waiter = continuation
        }
    }

    /// 살아 있는지 확인. `failPing()`을 켜면 끊긴 연결처럼 실패한다.
    func ping() throws {
        pingCount += 1
        if pingFails {
            throw STOMPError.notConnected
        }
    }

    func failPing() {
        pingFails = true
    }

    func handshakeStatusCode() -> Int? {
        stubbedStatusCode
    }

    func close() {
        closeCount += 1
        // 열려 있던 receive()는 연결 종료로 깨운다 — 실제 채널과 같은 모양.
        deliver(.failure(STOMPError.notConnected))
    }

    // MARK: - 테스트가 조작하는 입구

    /// 서버가 보낸 것처럼 텍스트 메시지를 흘려 넣는다.
    func push(_ text: String) {
        deliver(.success(.text(text)))
    }

    /// 소켓이 끊긴 것처럼 대기 중인 `receive()`를 실패시킨다.
    func fail(_ error: any Error) {
        deliver(.failure(error))
    }

    /// 지금까지 보낸 텍스트 프레임. 하트비트(개행만 있는 프레임)는 뺀다.
    var sentText: [String] {
        sentFrames.compactMap { frame in
            guard case let .text(text) = frame else { return nil }
            return text.trimmingCharacters(in: .newlines).isEmpty ? nil : text
        }
    }

    /// 보낸 프레임을 STOMP 프레임으로 되읽는다. 헤더까지 검증할 때 쓴다.
    var sentSTOMPFrames: [STOMPFrame] {
        sentText.flatMap { STOMPCodec.decode(Data($0.utf8)).frames }
    }

    func sentCount(of command: STOMPCommand) -> Int {
        sentSTOMPFrames.filter { $0.command == command.rawValue }.count
    }

    func firstSentFrame(_ command: STOMPCommand) -> STOMPFrame? {
        sentSTOMPFrames.first { $0.command == command.rawValue }
    }

    /// 서버 공통 오류 채널을 뺀 구독. 그건 클라이언트가 연결할 때마다 스스로 거는 것이라
    /// 대부분의 테스트에서는 관심사가 아니다.
    var roomSubscribes: [STOMPFrame] {
        sentSTOMPFrames.filter {
            $0.command == STOMPCommand.subscribe.rawValue
                && $0.headers[STOMPFrame.Header.destination] != STOMPClient.errorDestination
        }
    }

    // MARK: - 내부

    private func respond(to frame: WebSocketFrame) {
        for sent in STOMPCodec.decode(frame.payload).frames {
            switch sent.knownCommand {
            case .connect:
                push("CONNECTED\nversion:1.2\n\n\u{0}")
            case .subscribe:
                guard let receipt = sent.headers[STOMPFrame.Header.receipt] else { continue }
                push("RECEIPT\nreceipt-id:\(receipt)\n\n\u{0}")
            default:
                continue
            }
        }
    }

    private func deliver(_ result: Result<WebSocketFrame, any Error>) {
        if let waiter {
            self.waiter = nil
            waiter.resume(with: result)
        } else {
            queued.append(result)
        }
    }
}

/// 재연결마다 새 채널이 만들어지므로, 만들어진 채널을 순서대로 붙잡아 둔다.
/// `STOMPClient`가 동기 클로저로 채널을 만들기 때문에 actor가 아니라 잠금을 쓴다.
final class FakeChannelFactory: Sendable {

    private let created = OSAllocatedUnfairLock(initialState: [FakeWebSocketChannel]())
    private let failingCommands = OSAllocatedUnfairLock(initialState: Set<String>())
    private let autoRespond: Bool
    private let handshakeStatusCode: Int?
    private let initialFailure: (any Error)?

    init(
        autoRespond: Bool = true,
        handshakeStatusCode: Int? = nil,
        initialFailure: (any Error)? = nil
    ) {
        self.autoRespond = autoRespond
        self.handshakeStatusCode = handshakeStatusCode
        self.initialFailure = initialFailure
    }

    /// 지금부터 만들어지는 채널이 이 명령의 전송을 실패시킨다. 이미 만들어진 채널에도 적용된다.
    func failSends(of command: STOMPCommand) {
        failingCommands.withLock { $0.insert(command.rawValue) }
    }

    func stopFailingSends() {
        failingCommands.withLock { $0.removeAll() }
    }

    var channels: [FakeWebSocketChannel] {
        created.withLock { $0 }
    }

    func make() -> any WebSocketChannel {
        let failing = failingCommands
        let channel = FakeWebSocketChannel(
            autoRespond: autoRespond,
            handshakeStatusCode: handshakeStatusCode,
            initialFailure: initialFailure,
            shouldFailSend: { frame in failing.withLock { $0.contains(frame.command) } }
        )
        created.withLock { $0.append(channel) }
        return channel
    }
}

/// 비동기 작업이 끝났는지만 표시하는 깃발.
actor CompletionFlag {
    private(set) var isDone = false
    func mark() {
        isDone = true
    }
}

/// 스트림에 흘러온 이벤트를 모은다.
actor EventCollector {
    private(set) var events: [STOMPEvent] = []
    func append(_ event: STOMPEvent) {
        events.append(event)
    }
}
