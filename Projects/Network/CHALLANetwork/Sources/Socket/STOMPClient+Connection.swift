import Foundation

/// 읽기 루프·재연결·하트비트 — `STOMPClient`의 동작부.
/// 상태 선언과 공개 API는 `STOMPClient.swift`에 있다. 한 파일에 두기엔 길어 갈랐다.
extension STOMPClient {

    // MARK: - 읽기

    func startReadLoop(on channel: any WebSocketChannel, generation: Int) {
        readLoop?.cancel()
        readLoop = Task { [weak self] in
            // 한 프레임이 WebSocket 메시지 여러 개에 걸쳐 오므로 남은 꼬리를 이어 붙인다.
            var buffer = Data()
            while !Task.isCancelled {
                do {
                    try await buffer.append(channel.receive().payload)
                } catch {
                    await self?.connectionDropped(error, generation: generation)
                    return
                }

                let decoded = STOMPCodec.decode(buffer)
                buffer = decoded.remainder
                for frame in decoded.frames {
                    await self?.handle(frame, generation: generation)
                }
                if let error = decoded.error {
                    // 깨진 바이트만 버리고 연결은 유지한다. 같이 온 정상 프레임은 위에서 이미 처리했다.
                    await self?.noteMalformedFrame(error)
                }
            }
        }
    }

    /// 깨진 프레임은 연결을 끊지 않고 기록만 남긴다 — 원인 추적용이다.
    func noteMalformedFrame(_ error: STOMPError) {
        log.note("프레임을 해석하지 못했다: " + error.localizedDescription)
    }

    func handle(_ frame: STOMPFrame, generation: Int) async {
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
            route(frame)

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

    /// MESSAGE를 구독별 스트림으로 흘린다. 서버 공통 오류 채널만 따로 받아 로그로 남긴다.
    func route(_ frame: STOMPFrame) {
        guard let id = frame.headers[STOMPFrame.Header.subscription] else { return }
        guard id != errorSubscriptionID else {
            let body = String(bytes: frame.body, encoding: .utf8) ?? "<디코딩 불가>"
            log.note("서버 오류 채널: " + body)
            return
        }
        subscriptions[id]?.continuation.yield(.message(frame.body))
    }

    // MARK: - 끊김과 재연결

    func connectionDropped(_ error: any Error, generation: Int) async {
        // 이미 새 연결로 갈아탄 뒤 도착한 옛 연결의 끊김 통지는 버린다.
        // (백그라운드에서 끊고 곧바로 포그라운드로 돌아올 때 실제로 겹친다.)
        guard generation == connectionGeneration else { return }
        heartbeatTask?.cancel(); heartbeatTask = nil
        // 이 메서드는 읽기 루프 안에서만 불린다. 자기 자신을 취소하지 않고 참조만 놓는다.
        readLoop = nil
        connectTask = nil

        // 세대를 먼저 넘긴다. ERROR 프레임 경로로 들어오면 읽기 루프가 살아 있어서,
        // 곧이어 receive()가 실패하며 같은 끊김을 두 번 처리하게 된다.
        connectionGeneration += 1

        let statusCode = await channel?.handshakeStatusCode()
        await channel?.close()
        channel = nil
        wakeAllWaiters()

        let reason = String(describing: error)
        let handshake = statusCode.map(String.init) ?? "-"
        log.note("연결이 끊겼다 (handshake=\(handshake)): \(reason)")
        guard !subscriptions.isEmpty, !isBackgrounded, !isReconnectSuspended else { return }

        if isLikelyAuthFailure(statusCode: statusCode) {
            await handleAuthFailure()
        } else {
            scheduleReconnect()
        }
    }

    /// 401을 직접 볼 수 있으면 그걸 쓰고, 못 보면 "CONNECTED를 한 번도 못 받고 두 번 연속 실패"를 근거로 삼는다.
    /// 핸드셰이크가 401로 거절된 경우에만 인증 문제로 본다.
    ///
    /// "연속 실패"를 인증 실패로 넘겨짚지 않는다. 서버가 꺼져 있거나 경로가 틀렸거나
    /// 전파가 나쁠 때도 똑같이 연속 실패라, 그걸 인증 문제로 다루면 멀쩡한 세션을 건드리게 된다.
    func isLikelyAuthFailure(statusCode: Int?) -> Bool {
        statusCode == 401
    }

    /// 토큰을 한 번 갱신해 보고, 안 되면 재연결만 멈춘다.
    ///
    /// **여기서 세션을 만료시키지 않는다.** `TokenRefreshing`은 네트워크 장애일 때도 `false`를
    /// 돌려주기 때문에(`AuthTokenRefresher`가 그 경우 세션을 일부러 살려 둔다), 그 값을 만료로
    /// 해석하면 소켓이 잠깐 끊긴 것만으로 사용자가 로그인 화면으로 튕겨 나간다.
    /// 진짜로 만료됐다면 이어지는 REST 요청이 401을 받아 원래 경로로 처리한다.
    func handleAuthFailure() async {
        // 한 연결 주기에 갱신은 한 번만 시도한다.
        // 갱신은 성공하는데 ws 쪽 401이 계속되는 경우(권한 설정 문제 등) 무한히 돌면서
        // 리프레시 토큰을 계속 돌리게 되고, 그러다 진짜로 세션이 끊긴다.
        guard !didRefreshTokenThisCycle else {
            isReconnectSuspended = true
            finishAll(STOMPError.unauthorized)
            return
        }
        didRefreshTokenThisCycle = true

        let staleToken = await tokenProvider.accessToken()
        let refreshed = await tokenRefresher?.refreshToken(replacing: staleToken) ?? false
        guard refreshed else {
            // 멈추지 않으면 401 핸드셰이크를 1초마다 영원히 두들긴다.
            // 새 구독이 들어오면 그때 다시 시도한다 (`subscribe`가 이 값을 푼다).
            isReconnectSuspended = true
            finishAll(STOMPError.unauthorized)
            return
        }
        // 즉시가 아니라 백오프를 태운다. 갱신이 통해도 401이 반복될 수 있다.
        scheduleReconnect()
    }

    func scheduleReconnect(immediately: Bool = false) {
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

    func reconnect() async {
        guard !subscriptions.isEmpty, !isBackgrounded, !isReconnectSuspended else { return }
        do {
            try await ensureConnected()
            // 순차로 걸면 RECEIPT를 안 주는 destination 하나가 나머지를 통째로 막는다
            // (방 개수 × receiptTimeout 만큼 실시간 복구가 늦어진다).
            await withTaskGroup(of: Void.self) { group in
                for id in Array(subscriptions.keys) {
                    group.addTask { try? await self.sendSubscribe(id) }
                }
            }
            reconnectAttempt = 0
            // 스트림은 끊지 않는다. 받는 쪽이 이 신호를 보고 놓친 구간을 REST로 메운다.
            // 재구독이 실제로 나간 것에만 알린다 — 안 나간 구독에 알리면 받는 쪽이
            // 실시간이 붙은 줄 알고 재시도 카운트를 되돌린다.
            for subscription in subscriptions.values
                where subscription.sentOnGeneration == connectionGeneration {
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

    /// 서버가 인증 오류와 잘못된 destination 구독을 알리는 주소 (백엔드 명세).
    static let errorDestination = "/user/queue/errors"

    // MARK: - 구독 해제와 유휴 종료

    func release(_ id: String) async {
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
    func scheduleIdleDisconnect() {
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

    func disconnectIfIdle() async {
        guard subscriptions.isEmpty else { return }
        if let channel {
            try? await channel.send(.text(STOMPFrame.disconnect().encoded()))
        }
        // 위 await 사이에 새 구독이 들어왔을 수 있다(actor는 await마다 재진입한다).
        // 그대로 끊으면 구독은 살아 있는데 연결만 죽어, 끊김 통지도 없어 재연결조차 안 걸린다.
        guard subscriptions.isEmpty else { return }
        await teardownConnection()
    }

    func teardownConnection() async {
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

    // MARK: - 연결 확인

    /// 연결이 살아 있는지 주기적으로 확인한다.
    ///
    /// 서버가 STOMP 하트비트를 거절하면(`heart-beat=0,0`, 실서버가 그렇다) 양쪽 다 아무것도
    /// 보내지 않는다. 그 상태에서 연결이 끊기면 `receive()`는 오류를 내지 않고 그대로 매달려 있어,
    /// 앱은 죽은 소켓을 붙들고 영원히 기다린다 — 실기기에서 실제로 났다.
    /// 그래서 STOMP 하트비트를 못 보낼 때는 WebSocket ping으로 대신 확인한다.
    func startHeartbeat() {
        heartbeatTask?.cancel()
        let generation = connectionGeneration
        let interval = negotiatedHeartbeat > 0
            ? Duration.milliseconds(negotiatedHeartbeat)
            : Const.livenessInterval
        let usesSTOMPHeartbeat = negotiatedHeartbeat > 0
        let sleep = self.sleep
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await sleep(interval) } catch { return }
                await self?.checkLiveness(usingSTOMPHeartbeat: usesSTOMPHeartbeat, generation: generation)
            }
        }
    }

    /// 한 번 확인한다. 실패는 끊김으로 다룬다 — 삼키면 재연결이 영영 걸리지 않는다.
    func checkLiveness(usingSTOMPHeartbeat: Bool, generation: Int) async {
        guard generation == connectionGeneration, let channel else { return }
        do {
            if usingSTOMPHeartbeat {
                try await channel.send(.text("\n"))
            } else {
                try await channel.ping()
            }
        } catch {
            log.note("연결 확인에 실패했다: \(error)")
            await connectionDropped(error, generation: generation)
        }
    }

    // MARK: - 대기 정리

    func wakeAllWaiters() {
        connectedWaiter?.finish()
        connectedWaiter = nil
        for waiter in receiptWaiters.values {
            waiter.finish()
        }
        receiptWaiters.removeAll()
    }

    func finishAll(_ error: any Error) {
        let all = subscriptions
        subscriptions.removeAll()
        for subscription in all.values {
            subscription.continuation.finish(throwing: error)
        }
    }
}

private enum Const {

    /// STOMP 하트비트를 쓸 수 없을 때 연결이 살아 있는지 확인하는 주기.
    /// 짧으면 배터리를 먹고, 길면 끊긴 것을 늦게 안다.
    static let livenessInterval: Duration = .seconds(30)
}
