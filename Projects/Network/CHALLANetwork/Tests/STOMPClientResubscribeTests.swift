@testable import CHALLANetwork
import Foundation
import Testing

/// 연결이 끊긴 뒤 다시 거는 구간만 따로 본다.
/// 여기서 잘못되면 화면은 "실시간이 붙었다"고 믿은 채 아무것도 받지 못한다.
@Suite("STOMPClient — 재구독과 생명주기")
struct STOMPClientResubscribeTests {

    private let url = URL(string: "ws://a.com/api/v1/ws")!

    /// 재연결 백오프만 압축한다. 테스트가 지정한 짧은 타임아웃은 그대로 둔다.
    private static let compressedSleep: @Sendable (Duration) async throws -> Void = { duration in
        try await Task.sleep(for: duration >= .seconds(1) ? .milliseconds(5) : duration)
    }

    private func makeClient(factory: FakeChannelFactory) -> STOMPClient {
        STOMPClient(
            url: url,
            tokenProvider: FakeTokenProvider(token: "t"),
            tokenRefresher: nil,
            makeChannel: { factory.make() },
            sleep: Self.compressedSleep,
            connectTimeout: .milliseconds(300),
            receiptTimeout: .milliseconds(300),
            idleDisconnectDelay: .milliseconds(30),
            heartbeatMilliseconds: 0
        )
    }

    @Test("백그라운드에서는 구독해도 소켓을 열지 않고, 복귀할 때 함께 건다")
    func doesNotOpenSocketWhileBackgrounded() async throws {
        let factory = FakeChannelFactory()
        let client = makeClient(factory: factory)

        await client.applicationDidEnterBackground()
        let stream = try await client.subscribe(to: "/topic/a")
        let events = EventCollector()
        let consumer = Task { for try await event in stream {
            await events.append(event)
        } }
        defer { consumer.cancel() }
        try await Task.sleep(for: .milliseconds(20))

        // 곧 OS가 끊을 연결을 미리 만들지 않는다.
        #expect(factory.channels.isEmpty)

        await client.applicationWillEnterForeground()
        try await Task.sleep(for: .milliseconds(50))

        // 등록만 해 둔 구독이 복귀할 때 실제로 걸린다.
        #expect(factory.channels.count == 1)
        #expect(await factory.channels[0].roomSubscribes.count == 1)

        // 백그라운드에서 부른 subscribe는 구독 확정을 기다리지 않고 리턴한다.
        // 그래서 받는 쪽이 "구독됐다"고 믿고 REST를 먼저 부를 수 있는데,
        // 복귀할 때 오는 .resumed가 그 구간을 다시 메우게 한다. 이 신호가 없으면 조용히 빈다.
        #expect(await events.events == [.resumed])
    }

    // MARK: - 재구독 전송 실패

    @Test("재구독 SUBSCRIBE 전송이 실패하면 .resumed를 알리지 않는다")
    func doesNotAnnounceResumeWhenResubscribeSendFails() async throws {
        let factory = FakeChannelFactory()
        let client = makeClient(factory: factory)

        let stream = try await client.subscribe(to: "/topic/a")
        let events = EventCollector()
        let consumer = Task { for try await event in stream {
            await events.append(event)
        } }
        defer { consumer.cancel() }
        try await Task.sleep(for: .milliseconds(20))

        // 다음 연결에서는 SUBSCRIBE 전송이 깨진다.
        factory.failSends(of: .subscribe)
        await factory.channels[0].fail(STOMPError.notConnected)
        try await Task.sleep(for: .milliseconds(80))

        // 구독을 못 걸었으므로 실시간이 붙었다고 알리면 안 된다 —
        // 받는 쪽이 그 신호를 보고 재시도를 멈춘다.
        #expect(await events.events.isEmpty)
    }

    @Test("전송이 실패한 구독은 같은 연결에서 다시 걸 수 있다")
    func retriesSubscribeAfterSendFailureOnSameConnection() async throws {
        let factory = FakeChannelFactory()
        let client = makeClient(factory: factory)

        let stream = try await client.subscribe(to: "/topic/a")
        let consumer = Task { for try await _ in stream {} }
        defer { consumer.cancel() }
        try await Task.sleep(for: .milliseconds(20))

        factory.failSends(of: .subscribe)
        await factory.channels[0].fail(STOMPError.notConnected)
        try await Task.sleep(for: .milliseconds(80))

        let reconnected = try #require(factory.channels.last)
        let attemptsAfterFailure = await reconnected.roomSubscribes.count

        // 전송 실패로 남은 표시를 되돌렸으므로, 같은 연결에서 한 번 더 시도할 수 있다.
        factory.stopFailingSends()
        await client.applicationWillEnterForeground()
        try await Task.sleep(for: .milliseconds(50))

        #expect(await reconnected.roomSubscribes.count > attemptsAfterFailure)
    }

    // MARK: - 죽은 소켓 감지

    @Test("서버가 하트비트를 거절해도 ping으로 살아 있는지 확인한다")
    func pingsWhenServerDeclinesHeartbeat() async throws {
        // 실서버가 heart-beat=0,0으로 답한다. 그러면 양쪽 다 아무것도 보내지 않아
        // 연결이 끊겨도 receive()가 오류를 내지 않는다 — 확인할 수단이 ping뿐이다.
        let factory = FakeChannelFactory()
        let client = makeClient(factory: factory)

        let stream = try await client.subscribe(to: "/topic/a")
        let consumer = Task { for try await _ in stream {} }
        defer { consumer.cancel() }
        try await Task.sleep(for: .milliseconds(120))

        #expect(await factory.channels[0].pingCount > 0)
    }

    @Test("ping이 실패하면 끊긴 것으로 보고 다시 붙는다")
    func reconnectsWhenPingFails() async throws {
        let factory = FakeChannelFactory()
        let client = makeClient(factory: factory)

        let stream = try await client.subscribe(to: "/topic/a")
        let consumer = Task { for try await _ in stream {} }
        defer { consumer.cancel() }
        try await Task.sleep(for: .milliseconds(30))

        // 소켓이 조용히 죽는다. receive()는 아무 일도 없다는 듯 매달려 있다.
        await factory.channels[0].failPing()
        try await Task.sleep(for: .milliseconds(200))

        // 실패를 삼키면 죽은 소켓을 붙들고 영원히 기다린다 — 실기기에서 실제로 났다.
        #expect(factory.channels.count >= 2)
    }
}
