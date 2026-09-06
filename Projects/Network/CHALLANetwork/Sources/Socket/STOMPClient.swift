import Foundation

/// STOMP 연결 하나를 관리한다. 앱 전체가 이 인스턴스 하나를 공유한다.
///
/// 연결은 첫 구독이 걸 때 열리고 마지막 구독이 사라지면 잠시 뒤 닫힌다(`idleDisconnectDelay`).
/// 끊기면 백오프로 다시 붙고 살아 있던 구독을 모두 다시 건 뒤 각 스트림에 `.resumed`를 흘린다 —
/// 그래서 화면 쪽에는 재연결 코드가 생기지 않는다.
///
/// 대기(CONNECTED·RECEIPT)에 `CheckedContinuation` 대신 일회성 `AsyncStream`을 쓴다.
/// `CheckedContinuation`은 Task 취소를 무시해서, 화면을 벗어나면 그 자리에 영원히 주차된다.
public actor STOMPClient: STOMPClienting {

    // MARK: - 주입값

    private let url: URL
    private let tokenProvider: any TokenProvider
    private let tokenRefresher: (any TokenRefreshing)?
    private let onSessionExpired: @Sendable () -> Void
    private let makeChannel: @Sendable () -> any WebSocketChannel
    private let sleep: @Sendable (Duration) async throws -> Void
    private let connectTimeout: Duration
    private let receiptTimeout: Duration
    private let idleDisconnectDelay: Duration
    private let heartbeatMilliseconds: Int
    private let log: STOMPLogger

    // MARK: - 상태

    private struct Subscription {
        let id: String
        let destination: String
        /// 재연결 때 그대로 재사용한다 — 진행 중이던 구독 대기가 고아가 되지 않게.
        let receiptID: String
        let continuation: AsyncThrowingStream<STOMPEvent, any Error>.Continuation
    }

    /// 살아 있는 구독. 이 사전의 크기가 곧 참조 카운트다 (별도 정수를 두면 어긋난다).
    private var subscriptions: [String: Subscription] = [:]

    private var channel: (any WebSocketChannel)?
    private var connectTask: Task<Void, any Error>?
    private var readLoop: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var idleDisconnectTask: Task<Void, Never>?

    private var nextSubscriptionNumber = 0
    private var reconnectAttempt = 0
    /// 연결 세대. 옛 연결의 읽기 루프가 뒤늦게 보내는 통지로 새 연결이 무너지지 않게 하는 표식이다.
    private var connectionGeneration = 0
    private var consecutiveConnectFailures = 0

    private var connectedArrived = false
    /// CONNECTED로 협상된 송신 하트비트 간격(ms). 0이면 보내지 않는다.
    private var negotiatedHeartbeat = 0
    private var connectedWaiter: AsyncStream<Void>.Continuation?
    private var receiptWaiters: [String: AsyncStream<Void>.Continuation] = [:]
    /// 대기가 자리를 잡기 전에 도착한 RECEIPT.
    private var arrivedReceipts: Set<String> = []

    private var isBackgrounded = false
    private var isUnauthorized = false

    // MARK: - 생성

    /// 앱이 쓰는 생성자. 실제 `URLSession` 채널과 기본 타이밍을 쓴다.
    public init(
        url: URL,
        tokenProvider: any TokenProvider,
        tokenRefresher: (any TokenRefreshing)? = nil,
        onSessionExpired: @escaping @Sendable () -> Void = {},
        logLevel: STOMPLogger.Level = .none
    ) {
        self.init(
            logLevel: logLevel,
            url: url,
            tokenProvider: tokenProvider,
            tokenRefresher: tokenRefresher,
            onSessionExpired: onSessionExpired,
            makeChannel: { URLSessionWebSocketChannel() }
        )
    }

    /// 테스트용 생성자. 채널과 대기 시간을 갈아끼워 서버 없이, 기다리지 않고 검증한다.
    init(
        logLevel: STOMPLogger.Level = .none,
        url: URL,
        tokenProvider: any TokenProvider,
        tokenRefresher: (any TokenRefreshing)? = nil,
        onSessionExpired: @escaping @Sendable () -> Void = {},
        makeChannel: @escaping @Sendable () -> any WebSocketChannel,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        connectTimeout: Duration = .seconds(10),
        receiptTimeout: Duration = .seconds(3),
        idleDisconnectDelay: Duration = .seconds(20),
        heartbeatMilliseconds: Int = 10000
    ) {
        self.url = url
        self.tokenProvider = tokenProvider
        self.tokenRefresher = tokenRefresher
        self.onSessionExpired = onSessionExpired
        self.makeChannel = makeChannel
        self.sleep = sleep
        self.connectTimeout = connectTimeout
        self.receiptTimeout = receiptTimeout
        self.idleDisconnectDelay = idleDisconnectDelay
        self.heartbeatMilliseconds = heartbeatMilliseconds
        log = STOMPLogger(level: logLevel)
    }

    // MARK: - STOMPClienting

    public func subscribe(to destination: String) async throws -> AsyncThrowingStream<STOMPEvent, any Error> {
        guard !isUnauthorized else { throw STOMPError.unauthorized }

        idleDisconnectTask?.cancel()
        idleDisconnectTask = nil

        nextSubscriptionNumber += 1
        let id = "sub-\(nextSubscriptionNumber)"
        // 버퍼링 정책을 명시한다 — 기본값이 아닌 정책은 채팅을 조용히 버린다.
        let (stream, continuation) = AsyncThrowingStream<STOMPEvent, any Error>.makeStream(
            bufferingPolicy: .unbounded
        )

        // 연결을 시도하기 "전에" 등록한다. 그 사이 다른 경로가 구독 없음으로 보고 연결을 끊으면 안 된다.
        subscriptions[id] = Subscription(
            id: id,
            destination: destination,
            receiptID: "receipt-\(id)",
            continuation: continuation
        )
        continuation.onTermination = { [weak self] _ in
            // finish()·소비자 Task 취소·스트림 소멸 어느 경로로도 정확히 한 번 불린다.
            guard let self else { return }
            Task { await self.release(id) }
        }

        do {
            try await ensureConnected()
            try await sendSubscribe(id)
        } catch {
            subscriptions.removeValue(forKey: id)
            continuation.finish()
            throw error
        }
        return stream
    }

    public func applicationDidEnterBackground() async {
        isBackgrounded = true
        reconnectTask?.cancel(); reconnectTask = nil
        idleDisconnectTask?.cancel(); idleDisconnectTask = nil
        await teardownConnection()
    }

    public func applicationWillEnterForeground() async {
        isBackgrounded = false
        guard !subscriptions.isEmpty, !isUnauthorized else { return }
        // 백그라운드 동안 놓친 구간은 각 스트림의 `.resumed`를 받은 쪽이 REST로 메운다.
        reconnectAttempt = 0
        await reconnect()
    }
}

/// 아래는 위 actor의 동작부다. 같은 파일 안 extension으로 둔 이유는 두 가지다 —
/// 파일을 가르면 `private` 저장 프로퍼티에 닿지 못해 전부 internal로 열어야 하고,
/// 한 선언 안에 다 넣으면 타입 본문이 너무 길어진다.
extension STOMPClient {

    // MARK: - 연결

    /// 동시에 여러 구독이 들어와도 CONNECT는 한 번만 나간다.
    /// actor의 모든 await가 재진입 지점이라, memoize하지 않으면 연결이 두 개 열린다.
    private func ensureConnected() async throws {
        if let connectTask {
            return try await connectTask.value
        }
        let task = Task { try await self.performConnect() }
        connectTask = task
        do {
            try await task.value
        } catch {
            if connectTask == task {
                connectTask = nil
            }
            throw error
        }
    }

    private func performConnect() async throws {
        let channel = makeChannel()
        self.channel = channel
        connectedArrived = false
        connectionGeneration += 1
        let generation = connectionGeneration

        let token = await tokenProvider.accessToken()
        var request = URLRequest(url: url)
        if let token {
            // 서버가 핸드셰이크 단계에서 막으므로(무인증 GET이 401) 업그레이드 요청에 반드시 실어야 한다.
            request.setValue("Bearer \(token)", forHTTPHeaderField: STOMPFrame.Header.authorization)
        }
        await channel.open(request)
        startReadLoop(on: channel, generation: generation)

        let connect = STOMPFrame.connect(
            host: url.host() ?? "",
            token: token,
            heartbeatMilliseconds: heartbeatMilliseconds
        )
        log.sent(connect)
        try await channel.send(.text(connect.encoded()))

        try await withSTOMPTimeout(connectTimeout, sleep: sleep) { await self.parkForConnected() }
        guard connectedArrived else { throw STOMPError.connectTimeout }

        consecutiveConnectFailures = 0
        startHeartbeat()
    }

    private func sendSubscribe(_ id: String) async throws {
        guard let subscription = subscriptions[id], let channel else { return }
        let frame = STOMPFrame.subscribe(
            id: id,
            destination: subscription.destination,
            receipt: subscription.receiptID
        )
        log.sent(frame)
        try await channel.send(.text(frame.encoded()))
        await awaitReceipt(subscription.receiptID)
    }

    /// RECEIPT가 오지 않아도 실패로 보지 않는다 — SUBSCRIBE 프레임은 이미 소켓에 실렸고,
    /// STOMP는 한 연결 안에서 순서를 보장하므로 이어지는 REST 조회와 어긋나지 않는다.
    /// (브로커 설정에 따라 RECEIPT를 아예 보내지 않기도 한다.)
    private func awaitReceipt(_ receiptID: String) async {
        try? await withSTOMPTimeout(receiptTimeout, sleep: sleep) { await self.parkForReceipt(receiptID) }
        receiptWaiters.removeValue(forKey: receiptID)?.finish()
    }

    private func parkForReceipt(_ receiptID: String) async {
        if arrivedReceipts.remove(receiptID) != nil {
            return
        }
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        receiptWaiters[receiptID] = continuation
        for await _ in stream {
            break
        }
    }

    private func parkForConnected() async {
        if connectedArrived {
            return
        }
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        connectedWaiter = continuation
        for await _ in stream {
            break
        }
    }

    // MARK: - 읽기

    private func startReadLoop(on channel: any WebSocketChannel, generation: Int) {
        readLoop?.cancel()
        readLoop = Task { [weak self] in
            // 한 프레임이 WebSocket 메시지 여러 개에 걸쳐 오므로 남은 꼬리를 이어 붙인다.
            var buffer = Data()
            while !Task.isCancelled {
                do {
                    try await buffer.append(channel.receive().payload)
                    let decoded = try STOMPCodec.decode(buffer)
                    buffer = decoded.remainder
                    for frame in decoded.frames {
                        await self?.handle(frame, generation: generation)
                    }
                } catch let error as STOMPError where error.isMalformedFrame {
                    buffer = Data() // 깨진 바이트만 버리고 계속 읽는다
                } catch {
                    await self?.connectionDropped(error, generation: generation)
                    return
                }
            }
        }
    }

    private func handle(_ frame: STOMPFrame, generation: Int) async {
        log.received(frame)
        guard generation == connectionGeneration else { return }
        switch frame.knownCommand {
        case .connected:
            connectedArrived = true
            negotiatedHeartbeat = stompOutgoingHeartbeat(
                clientCanSend: heartbeatMilliseconds,
                connectedHeader: frame.headers[STOMPFrame.Header.heartBeat]
            )
            connectedWaiter?.finish()
            connectedWaiter = nil

        case .message:
            guard
                let id = frame.headers[STOMPFrame.Header.subscription],
                let subscription = subscriptions[id]
            else { return }
            subscription.continuation.yield(.message(frame.body))

        case .receipt:
            guard let receiptID = frame.headers[STOMPFrame.Header.receiptID] else { return }
            if let waiter = receiptWaiters.removeValue(forKey: receiptID) {
                waiter.finish()
            } else {
                arrivedReceipts.insert(receiptID)
            }

        case .error:
            // 명세상 서버는 ERROR 뒤 연결을 닫는다. 끊김과 같은 경로로 처리한다.
            let message = frame.headers[STOMPFrame.Header.message] ?? ""
            await connectionDropped(STOMPError.server(message: message), generation: generation)

        default:
            return
        }
    }

    // MARK: - 끊김과 재연결

    private func connectionDropped(_ error: any Error, generation: Int) async {
        // 이미 새 연결로 갈아탄 뒤 도착한 옛 연결의 끊김 통지는 버린다.
        // (백그라운드에서 끊고 곧바로 포그라운드로 돌아올 때 실제로 겹친다.)
        guard generation == connectionGeneration else { return }
        heartbeatTask?.cancel(); heartbeatTask = nil
        // 이 메서드는 읽기 루프 안에서만 불린다. 자기 자신을 취소하지 않고 참조만 놓는다.
        readLoop = nil
        connectTask = nil

        let statusCode = await channel?.handshakeStatusCode()
        if !connectedArrived {
            consecutiveConnectFailures += 1
        }
        await channel?.close()
        channel = nil
        wakeAllWaiters()

        let reason = String(describing: error)
        let handshake = statusCode.map(String.init) ?? "-"
        log.note("연결이 끊겼다 (handshake=\(handshake)): \(reason)")
        guard !subscriptions.isEmpty, !isBackgrounded, !isUnauthorized else { return }

        if isLikelyAuthFailure(statusCode: statusCode) {
            await handleAuthFailure()
        } else {
            scheduleReconnect()
        }
    }

    /// 401을 직접 볼 수 있으면 그걸 쓰고, 못 보면 "CONNECTED를 한 번도 못 받고 두 번 연속 실패"를 근거로 삼는다.
    private func isLikelyAuthFailure(statusCode: Int?) -> Bool {
        if statusCode == 401 {
            return true
        }
        return !connectedArrived && consecutiveConnectFailures >= 2
    }

    private func handleAuthFailure() async {
        let staleToken = await tokenProvider.accessToken()
        let refreshed = await tokenRefresher?.refreshToken(replacing: staleToken) ?? false
        guard refreshed else {
            // 여기서 멈추지 않으면 401 핸드셰이크를 1초마다 영원히 두들긴다.
            isUnauthorized = true
            onSessionExpired()
            finishAll(STOMPError.unauthorized)
            return
        }
        consecutiveConnectFailures = 0
        scheduleReconnect(immediately: true)
    }

    private func scheduleReconnect(immediately: Bool = false) {
        reconnectTask?.cancel()
        let delay = immediately ? .zero : Self.backoff(attempt: reconnectAttempt)
        if !immediately {
            reconnectAttempt += 1
        }

        let sleep = self.sleep
        reconnectTask = Task { [weak self] in
            if delay > .zero {
                do { try await sleep(delay) } catch { return }
            }
            guard !Task.isCancelled else { return }
            await self?.reconnect()
        }
    }

    private func reconnect() async {
        guard !subscriptions.isEmpty, !isBackgrounded, !isUnauthorized else { return }
        do {
            try await ensureConnected()
            for id in Array(subscriptions.keys) {
                try await sendSubscribe(id)
            }
            reconnectAttempt = 0
            // 스트림은 끊지 않는다. 받는 쪽이 이 신호를 보고 놓친 구간을 REST로 메운다.
            for subscription in subscriptions.values {
                subscription.continuation.yield(.resumed)
            }
        } catch {
            scheduleReconnect()
        }
    }

    static func backoff(attempt: Int) -> Duration {
        .seconds(backoffSeconds[min(attempt, backoffSeconds.count - 1)])
    }

    private static let backoffSeconds = [1, 2, 4, 8, 30]

    // MARK: - 구독 해제와 유휴 종료

    private func release(_ id: String) async {
        // 제거를 먼저 해서 어떤 경로로 두 번 불려도 한 번만 동작하게 한다.
        guard let subscription = subscriptions.removeValue(forKey: id) else { return }
        receiptWaiters.removeValue(forKey: subscription.receiptID)?.finish()
        arrivedReceipts.remove(subscription.receiptID)

        if let channel {
            try? await channel.send(.text(STOMPFrame.unsubscribe(id: id).encoded()))
        }
        scheduleIdleDisconnect()
    }

    /// 바로 끊지 않고 잠깐 둔다 — 방 상세와 채팅을 오갈 때마다 핸드셰이크를 다시 하지 않도록.
    private func scheduleIdleDisconnect() {
        guard subscriptions.isEmpty else { return }
        idleDisconnectTask?.cancel()

        let sleep = self.sleep
        let delay = idleDisconnectDelay
        idleDisconnectTask = Task { [weak self] in
            do { try await sleep(delay) } catch { return }
            guard !Task.isCancelled else { return }
            await self?.disconnectIfIdle()
        }
    }

    private func disconnectIfIdle() async {
        guard subscriptions.isEmpty else { return }
        if let channel {
            try? await channel.send(.text(STOMPFrame.disconnect().encoded()))
        }
        await teardownConnection()
    }

    private func teardownConnection() async {
        // 세대를 넘겨 옛 읽기 루프의 통지를 미리 무효화한다.
        connectionGeneration += 1
        heartbeatTask?.cancel(); heartbeatTask = nil
        readLoop?.cancel(); readLoop = nil
        connectTask = nil
        await channel?.close()
        channel = nil
        connectedArrived = false
        wakeAllWaiters()
    }

    // MARK: - 하트비트

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        // 서버가 "받지 않겠다"고 답하면 보내지 않는다 (STOMP 1.2의 heart-beat 협상).
        guard negotiatedHeartbeat > 0 else {
            heartbeatTask = nil
            return
        }
        let interval = Duration.milliseconds(negotiatedHeartbeat)
        let sleep = self.sleep
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await sleep(interval) } catch { return }
                await self?.sendHeartbeat()
            }
        }
    }

    private func sendHeartbeat() async {
        try? await channel?.send(.text("\n"))
    }

    // MARK: - 대기 정리

    private func wakeAllWaiters() {
        connectedWaiter?.finish()
        connectedWaiter = nil
        for waiter in receiptWaiters.values {
            waiter.finish()
        }
        receiptWaiters.removeAll()
    }

    private func finishAll(_ error: any Error) {
        let all = subscriptions
        subscriptions.removeAll()
        for subscription in all.values {
            subscription.continuation.finish(throwing: error)
        }
    }
}
