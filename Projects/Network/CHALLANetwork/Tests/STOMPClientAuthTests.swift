@testable import CHALLANetwork
import Foundation
import Testing

/// 소켓이 인증 실패를 어떻게 다루는지 — 특히 **세션을 건드리지 않는지**.
@Suite("STOMPClient — 인증")
struct STOMPClientAuthTests {

    private let url = URL(string: "ws://a.com/api/v1/ws")!

    /// 재연결 백오프·유휴 대기(1초 이상)만 압축한다. 테스트가 지정한 짧은 타임아웃은 그대로 둔다.
    private static let compressedSleep: @Sendable (Duration) async throws -> Void = { duration in
        try await Task.sleep(for: duration >= .seconds(1) ? .milliseconds(5) : duration)
    }

    private func makeClient(
        factory: FakeChannelFactory,
        refresher: (any TokenRefreshing)? = nil,
        connectTimeout: Duration = .milliseconds(300),
        receiptTimeout: Duration = .milliseconds(300),
        idleDisconnectDelay: Duration = .milliseconds(30)
    ) -> STOMPClient {
        STOMPClient(
            url: url,
            tokenProvider: FakeTokenProvider(token: "t"),
            tokenRefresher: refresher,
            makeChannel: { factory.make() },
            sleep: Self.compressedSleep,
            connectTimeout: connectTimeout,
            receiptTimeout: receiptTimeout,
            idleDisconnectDelay: idleDisconnectDelay,
            heartbeatMilliseconds: 0 // 하트비트는 이 스위트의 관심사가 아니다
        )
    }

    // MARK: - 인증

    @Test("401이면 토큰을 갱신하고 다시 붙는다")
    func refreshesTokenOn401() async throws {
        let factory = FakeChannelFactory(handshakeStatusCode: 401)
        let refresher = FakeTokenRefresher(result: true)
        let client = makeClient(factory: factory, refresher: refresher)

        let stream = try await client.subscribe(to: "/topic/a")
        let consumer = Task { for try await _ in stream {} }
        try await Task.sleep(for: .milliseconds(20))

        await factory.channels[0].fail(URLError(.userAuthenticationRequired))
        try await Task.sleep(for: .milliseconds(150))

        #expect(refresher.callCount == 1)
        #expect(factory.channels.count == 2)
        consumer.cancel()
    }

    @Test("갱신까지 실패하면 재연결을 멈추되 세션은 건드리지 않는다")
    func stopsReconnectingWhenRefreshFails() async throws {
        let factory = FakeChannelFactory(handshakeStatusCode: 401)
        let client = makeClient(factory: factory, refresher: FakeTokenRefresher(result: false))

        let stream = try await client.subscribe(to: "/topic/a")
        let consumer = Task { for try await _ in stream {} }
        try await Task.sleep(for: .milliseconds(20))

        await factory.channels[0].fail(URLError(.userAuthenticationRequired))
        try await Task.sleep(for: .milliseconds(150))

        // 401 핸드셰이크를 영원히 두들기지 않는다.
        #expect(factory.channels.count == 1)
        consumer.cancel()
    }

    @Test("소켓이 끊겨도(401이 아니면) 토큰 갱신을 시도하지 않는다")
    func doesNotTouchSessionOnPlainDisconnect() async throws {
        // 서버가 꺼졌거나 전파가 나쁜 상황. 핸드셰이크 상태 코드가 없다.
        let factory = FakeChannelFactory()
        let refresher = FakeTokenRefresher(result: false)
        let client = makeClient(factory: factory, refresher: refresher)

        let stream = try await client.subscribe(to: "/topic/a")
        let consumer = Task { for try await _ in stream {} }
        try await Task.sleep(for: .milliseconds(20))

        await factory.channels[0].fail(URLError(.networkConnectionLost))
        try await Task.sleep(for: .milliseconds(150))

        // 인증 문제가 아니므로 갱신을 부르지 않고, 그냥 다시 붙는다.
        #expect(refresher.callCount == 0)
        #expect(factory.channels.count == 2)
        consumer.cancel()
    }

    @Test("재연결을 멈춘 뒤에도 새 구독이 오면 다시 시도한다 (재로그인)")
    func resumesOnNewSubscription() async throws {
        let factory = FakeChannelFactory(handshakeStatusCode: 401)
        let client = makeClient(factory: factory, refresher: FakeTokenRefresher(result: false))

        let stream = try await client.subscribe(to: "/topic/a")
        let consumer = Task { for try await _ in stream {} }
        try await Task.sleep(for: .milliseconds(20))
        await factory.channels[0].fail(URLError(.userAuthenticationRequired))
        try await Task.sleep(for: .milliseconds(150))
        consumer.cancel()

        // 재로그인 뒤 새 화면이 구독을 걸면 다시 붙어야 한다.
        let retry = try await client.subscribe(to: "/topic/b")
        let retryConsumer = Task { for try await _ in retry {} }
        #expect(factory.channels.count == 2)
        retryConsumer.cancel()
    }

    // MARK: - 첫 핸드셰이크부터 401인 경우

    @Test("첫 연결부터 401이면 토큰을 한 번 갱신하고 subscribe는 실패로 돌아온다")
    func refreshesOnceWhenFirstHandshakeIs401() async throws {
        // 위 테스트들은 CONNECTED 뒤에 401이 나는 경우다. 여기는 업그레이드 자체가 막히는 경우 —
        // 토큰이 만료된 채 앱을 켠 첫 화면이 이 경로로 들어온다.
        let factory = FakeChannelFactory(
            handshakeStatusCode: 401,
            initialFailure: URLError(.userAuthenticationRequired)
        )
        let refresher = FakeTokenRefresher(result: true)
        let client = makeClient(factory: factory, refresher: refresher)

        await #expect(throws: (any Error).self) {
            _ = try await client.subscribe(to: "/topic/a")
        }
        try await Task.sleep(for: .milliseconds(50))

        // 갱신은 한 번만. 여러 번 돌면 리프레시 토큰이 소진돼 진짜로 세션이 끊긴다.
        #expect(refresher.callCount == 1)
    }

    @Test("첫 핸드셰이크가 401이고 갱신도 실패하면 소켓을 다시 두들기지 않는다")
    func stopsWhenFirstHandshakeIs401AndRefreshFails() async throws {
        let factory = FakeChannelFactory(
            handshakeStatusCode: 401,
            initialFailure: URLError(.userAuthenticationRequired)
        )
        let client = makeClient(factory: factory, refresher: FakeTokenRefresher(result: false))

        await #expect(throws: (any Error).self) {
            _ = try await client.subscribe(to: "/topic/a")
        }
        try await Task.sleep(for: .milliseconds(80))

        #expect(factory.channels.count == 1)
    }
}
