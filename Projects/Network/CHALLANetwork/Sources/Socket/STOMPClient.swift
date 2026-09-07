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

    //
    // 아래 값들에 `private`을 붙이지 않은 이유: 이 actor의 동작부가 파일 길이 때문에
    // `STOMPClient+Connection.swift`로 갈라져 있고, `private`은 파일 단위라 그쪽에서 닿지 못한다.
    // 모듈 밖으로는 여전히 보이지 않는다.

    let url: URL
    let tokenProvider: any TokenProvider
    let tokenRefresher: (any TokenRefreshing)?
    let makeChannel: @Sendable () -> any WebSocketChannel
    let sleep: @Sendable (Duration) async throws -> Void
    let connectTimeout: Duration
    let receiptTimeout: Duration
    let idleDisconnectDelay: Duration
    let heartbeatMilliseconds: Int
    let log: STOMPLogger

    // MARK: - 상태

    struct Subscription {
        let id: String
        let destination: String
        /// 재연결 때 그대로 재사용한다 — 진행 중이던 구독 대기가 고아가 되지 않게.
        let receiptID: String
        /// 이 구독을 실제로 보낸 연결의 세대. 재연결이 이미 걸린 구독을 또 보내지 않게 하는 표식이다.
        var sentOnGeneration: Int?
        let continuation: AsyncThrowingStream<STOMPEvent, any Error>.Continuation
    }

    /// 살아 있는 구독. 이 사전의 크기가 곧 참조 카운트다 (별도 정수를 두면 어긋난다).
    var subscriptions: [String: Subscription] = [:]

    var channel: (any WebSocketChannel)?
    var connectTask: Task<Void, any Error>?
    var readLoop: Task<Void, Never>?
    var heartbeatTask: Task<Void, Never>?
    var reconnectTask: Task<Void, Never>?
    var idleDisconnectTask: Task<Void, Never>?

    var nextSubscriptionNumber = 0
    var reconnectAttempt = 0
    /// 연결 세대. 옛 연결의 읽기 루프가 뒤늦게 보내는 통지로 새 연결이 무너지지 않게 하는 표식이다.
    var connectionGeneration = 0
    /// 이번 연결 주기에서 토큰 갱신을 이미 시도했는지. CONNECTED를 받으면 풀린다.
    var didRefreshTokenThisCycle = false

    var connectedArrived = false
    /// CONNECTED로 협상된 송신 하트비트 간격(ms). 0이면 보내지 않는다.
    var negotiatedHeartbeat = 0
    /// 서버 공통 오류 채널의 구독 id. 참조 카운트(`subscriptions`)에는 넣지 않는다 —
    /// 이 구독만으로 연결을 살려 둘 이유가 없다.
    let errorSubscriptionID = "sub-errors"
    var connectedWaiter: AsyncStream<Void>.Continuation?
    var receiptWaiters: [String: AsyncStream<Void>.Continuation] = [:]
    /// 대기가 자리를 잡기 전에 도착한 RECEIPT.
    var arrivedReceipts: Set<String> = []

    var isBackgrounded = false
    /// 인증 갱신까지 실패해 재연결을 멈춘 상태. 새 구독이 들어오면 풀린다 —
    /// 재로그인 뒤에도 앱을 껐다 켤 때까지 실시간이 죽어 있으면 안 된다.
    var isReconnectSuspended = false

    // MARK: - 생성

    /// 앱이 쓰는 생성자. 실제 `URLSession` 채널과 기본 타이밍을 쓴다.
    public init(
        url: URL,
        tokenProvider: any TokenProvider,
        tokenRefresher: (any TokenRefreshing)? = nil,
        logLevel: STOMPLogger.Level = .none
    ) {
        self.init(
            logLevel: logLevel,
            url: url,
            tokenProvider: tokenProvider,
            tokenRefresher: tokenRefresher,
            makeChannel: { URLSessionWebSocketChannel() }
        )
    }

    /// 테스트용 생성자. 채널과 대기 시간을 갈아끼워 서버 없이, 기다리지 않고 검증한다.
    init(
        logLevel: STOMPLogger.Level = .none,
        url: URL,
        tokenProvider: any TokenProvider,
        tokenRefresher: (any TokenRefreshing)? = nil,
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
        // 새 구독은 다시 시도해 볼 기회다. 재로그인 직후가 이 경로로 들어온다.
        isReconnectSuspended = false

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
            sentOnGeneration: nil,
            continuation: continuation
        )
        continuation.onTermination = { [weak self] _ in
            // finish()·소비자 Task 취소·스트림 소멸 어느 경로로도 정확히 한 번 불린다.
            guard let self else { return }
            Task { await self.release(id) }
        }

        // 백그라운드에서는 소켓을 열지 않는다. 등록만 해 두면 포그라운드 복귀 때
        // `reconnect()`가 이 구독까지 함께 건다 — 여기서 열면 OS가 곧 끊을 연결을
        // 만들어 두고, 그 끊김이 재연결 루프를 깨운다.
        guard !isBackgrounded else { return stream }

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
        guard !subscriptions.isEmpty, !isReconnectSuspended else { return }
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
    func ensureConnected() async throws {
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
        // 앞선 시도가 타임아웃으로 빠져나갔으면 그 채널이 아직 열려 있다. 닫지 않으면 소켓이 쌓인다.
        await channel?.close()

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

        do {
            try await withSTOMPTimeout(connectTimeout, sleep: sleep) { await self.parkForConnected() }
        } catch {
            // 소켓은 열렸는데 CONNECTED가 오지 않은 경우다. 정리하지 않으면 읽기 루프와 함께
            // 프로세스가 끝날 때까지 열린 채 남는다.
            await teardownConnection()
            throw error
        }
        guard connectedArrived else {
            await teardownConnection()
            throw STOMPError.connectTimeout
        }

        didRefreshTokenThisCycle = false
        await subscribeToErrorChannel(on: channel)
        startHeartbeat()
    }

    /// 서버가 인증 오류와 잘못된 destination 구독을 알리는 공통 채널.
    /// 여기로 오는 것은 화면에 전달하지 않고 로그로만 남긴다. 원인 추적용이다.
    private func subscribeToErrorChannel(on channel: any WebSocketChannel) async {
        let frame = STOMPFrame.subscribe(
            id: errorSubscriptionID,
            destination: Self.errorDestination,
            receipt: "receipt-" + errorSubscriptionID
        )
        log.sent(frame)
        try? await channel.send(.text(frame.encoded()))
    }

    func sendSubscribe(_ id: String) async throws {
        guard var subscription = subscriptions[id], let channel else { return }
        // 이미 이 연결에서 건 구독은 다시 보내지 않는다. 같은 연결에 같은 id를 두 번 보내면
        // 브로커가 ERROR로 답하고 연결을 닫는다.
        guard subscription.sentOnGeneration != connectionGeneration else { return }
        let generation = connectionGeneration
        // 보내기 "전에" 표시해 둔다 — 표시가 없으면 겹쳐 들어온 재구독이 같은 프레임을 두 번 보낸다.
        // 대신 전송이 실패하면 되돌린다. 실패한 채로 표시를 남기면 이 연결에서 다시 걸 기회가
        // 영영 사라지고, `reconnect()`가 보내지도 못한 구독에 `.resumed`를 알린다.
        subscription.sentOnGeneration = generation
        subscriptions[id] = subscription
        let frame = STOMPFrame.subscribe(
            id: id,
            destination: subscription.destination,
            receipt: subscription.receiptID
        )
        log.sent(frame)
        do {
            try await channel.send(.text(frame.encoded()))
        } catch {
            clearSentGeneration(id, ifStillAt: generation)
            throw error
        }
        await awaitReceipt(subscription.receiptID)
    }

    /// 전송에 실패한 구독의 세대 표시를 되돌린다.
    ///
    /// 전송을 기다리는 동안 actor가 재진입해 구독이 해제되거나 다시 걸렸을 수 있다.
    /// 그래서 "내가 표시한 그 세대 그대로일 때"만 지운다 — 아니면 남의 표시를 지운다.
    func clearSentGeneration(_ id: String, ifStillAt generation: Int) {
        guard var subscription = subscriptions[id],
              subscription.sentOnGeneration == generation else { return }
        subscription.sentOnGeneration = nil
        subscriptions[id] = subscription
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
}
