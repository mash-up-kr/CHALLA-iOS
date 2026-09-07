@testable import CHALLANetwork
import Foundation
import Testing

@Suite("STOMPClient")
struct STOMPClientTests {

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

    // MARK: - 연결

    @Test("동시에 두 번 구독해도 CONNECT는 한 번만 나간다")
    func concurrentSubscribesShareOneConnect() async throws {
        let factory = FakeChannelFactory()
        let client = makeClient(factory: factory)

        let first = Task { try await client.subscribe(to: "/topic/room/1/chat") }
        let second = Task { try await client.subscribe(to: "/topic/room/1/member-joined") }
        _ = try await first.value
        _ = try await second.value

        #expect(factory.channels.count == 1)
        #expect(await factory.channels[0].sentCount(of: .connect) == 1)
        #expect(await factory.channels[0].roomSubscribes.count == 2)
    }

    @Test("업그레이드 요청과 CONNECT 프레임 양쪽에 토큰을 싣는다")
    func tokenOnBothHandshakeAndConnectFrame() async throws {
        let factory = FakeChannelFactory()
        let client = makeClient(factory: factory)
        let stream = try await client.subscribe(to: "/topic/a")
        let consumer = Task { for try await _ in stream {} }
        defer { consumer.cancel() }

        let channel = factory.channels[0]
        let request = await channel.openedRequests.first
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer t")
        #expect(await channel.firstSentFrame(.connect)?.headers["Authorization"] == "Bearer t")
    }

    // MARK: - 구독 확정

    @Test("RECEIPT가 오기 전에는 subscribe가 리턴하지 않는다")
    func subscribeWaitsForReceipt() async throws {
        let factory = FakeChannelFactory(autoRespond: false)
        let client = makeClient(factory: factory, receiptTimeout: .milliseconds(900))
        let finished = CompletionFlag()

        let task = Task {
            _ = try await client.subscribe(to: "/topic/a")
            await finished.mark()
        }

        try await Task.sleep(for: .milliseconds(30))
        await factory.channels[0].push("CONNECTED\nversion:1.2\n\n\u{0}")
        try await Task.sleep(for: .milliseconds(50))

        // SUBSCRIBE는 나갔지만 RECEIPT를 못 받아 아직 리턴하지 않았다.
        #expect(await factory.channels[0].roomSubscribes.count == 1)
        #expect(await finished.isDone == false)

        await factory.channels[0].push("RECEIPT\nreceipt-id:receipt-sub-1\n\n\u{0}")
        try await task.value
        #expect(await finished.isDone)
    }

    @Test("RECEIPT가 오지 않아도 타임아웃 뒤에는 구독을 성사시킨다")
    func subscribeSucceedsWithoutReceipt() async throws {
        // CONNECTED만 답하고 RECEIPT는 보내지 않는 서버를 흉내 낸다.
        let factory = FakeChannelFactory(autoRespond: false)
        let client = makeClient(factory: factory, receiptTimeout: .milliseconds(50))

        let task = Task { try await client.subscribe(to: "/topic/a") }
        try await Task.sleep(for: .milliseconds(30))
        await factory.channels[0].push("CONNECTED\nversion:1.2\n\n\u{0}")

        _ = try await task.value // 타임아웃 뒤 정상 리턴한다
        #expect(await factory.channels[0].roomSubscribes.count == 1)
    }

    // MARK: - 메시지 전달

    @Test("MESSAGE를 subscription 헤더에 해당하는 스트림에만 흘린다")
    func routesMessageToItsSubscription() async throws {
        let factory = FakeChannelFactory()
        let client = makeClient(factory: factory)

        let chat = try await client.subscribe(to: "/topic/room/1/chat")
        let joined = try await client.subscribe(to: "/topic/room/1/member-joined")

        let chatEvents = EventCollector()
        let joinedEvents = EventCollector()
        let chatConsumer = Task { for try await event in chat {
            await chatEvents.append(event)
        } }
        let joinedConsumer = Task { for try await event in joined {
            await joinedEvents.append(event)
        } }

        try await Task.sleep(for: .milliseconds(20))
        await factory.channels[0].push("MESSAGE\nsubscription:sub-1\n\n{\"chat\":1}\u{0}")
        try await Task.sleep(for: .milliseconds(30))

        #expect(await chatEvents.events == [.message(Data("{\"chat\":1}".utf8))])
        #expect(await joinedEvents.events.isEmpty)

        chatConsumer.cancel()
        joinedConsumer.cancel()
    }

    // MARK: - 구독 해제와 유휴 종료

    @Test("소비자 Task를 취소하면 UNSUBSCRIBE가 정확히 한 번 나간다")
    func cancellingConsumerUnsubscribesOnce() async throws {
        let factory = FakeChannelFactory()
        let client = makeClient(factory: factory, idleDisconnectDelay: .seconds(30))

        let stream = try await client.subscribe(to: "/topic/a")
        let consumer = Task { for try await _ in stream {} }
        try await Task.sleep(for: .milliseconds(20))

        consumer.cancel()
        try await Task.sleep(for: .milliseconds(60))

        #expect(await factory.channels[0].sentCount(of: .unsubscribe) == 1)
    }

    @Test("마지막 구독이 사라지면 잠시 뒤 DISCONNECT를 보낸다")
    func disconnectsAfterIdleDelay() async throws {
        let factory = FakeChannelFactory()
        let client = makeClient(factory: factory, idleDisconnectDelay: .milliseconds(30))

        let stream = try await client.subscribe(to: "/topic/a")
        let consumer = Task { for try await _ in stream {} }
        try await Task.sleep(for: .milliseconds(20))
        consumer.cancel()

        try await Task.sleep(for: .milliseconds(120))
        #expect(await factory.channels[0].sentCount(of: .disconnect) == 1)
        #expect(await factory.channels[0].closeCount == 1)
    }

    @Test("유휴 대기 중에 다시 구독하면 연결을 끊지 않는다 (화면 이동마다 재연결 방지)")
    func resubscribingDuringLingerKeepsConnection() async throws {
        let factory = FakeChannelFactory()
        let client = makeClient(factory: factory, idleDisconnectDelay: .milliseconds(200))

        let first = try await client.subscribe(to: "/topic/a")
        let consumer = Task { for try await _ in first {} }
        try await Task.sleep(for: .milliseconds(20))
        consumer.cancel()

        try await Task.sleep(for: .milliseconds(40)) // 유휴 대기 중
        let second = try await client.subscribe(to: "/topic/b")
        let secondConsumer = Task { for try await _ in second {} }
        try await Task.sleep(for: .milliseconds(250)) // 원래 대기가 끝났을 시각을 지나서

        #expect(factory.channels.count == 1)
        #expect(await factory.channels[0].sentCount(of: .disconnect) == 0)
        #expect(await factory.channels[0].sentCount(of: .connect) == 1)
        secondConsumer.cancel()
    }

    // MARK: - 재연결

    @Test("끊기면 다시 붙어 구독을 재생하고 .resumed를 흘린다 (스트림은 끊지 않는다)")
    func reconnectsAndResubscribes() async throws {
        let factory = FakeChannelFactory()
        let client = makeClient(factory: factory)

        let stream = try await client.subscribe(to: "/topic/room/1/chat")
        let events = EventCollector()
        let consumer = Task { for try await event in stream {
            await events.append(event)
        } }
        try await Task.sleep(for: .milliseconds(20))

        await factory.channels[0].fail(URLError(.networkConnectionLost))
        try await Task.sleep(for: .milliseconds(150))

        #expect(factory.channels.count == 2)
        #expect(await factory.channels[1].sentCount(of: .connect) == 1)
        #expect(await factory.channels[1].roomSubscribes.count == 1)
        // 진행 중이던 구독 대기가 고아가 되지 않게 receipt id를 그대로 재사용한다.
        #expect(await factory.channels[1].roomSubscribes.first?.headers["receipt"] == "receipt-sub-1")
        #expect(await events.events == [.resumed])

        consumer.cancel()
    }

    @Test("연결하면 서버 공통 오류 채널을 함께 구독한다")
    func subscribesToErrorChannel() async throws {
        let factory = FakeChannelFactory()
        let client = makeClient(factory: factory)
        let stream = try await client.subscribe(to: "/topic/a")
        let consumer = Task { for try await _ in stream {} }
        defer { consumer.cancel() }

        let destinations = await factory.channels[0].sentSTOMPFrames
            .filter { $0.command == STOMPCommand.subscribe.rawValue }
            .compactMap { $0.headers[STOMPFrame.Header.destination] }
        #expect(destinations.contains(STOMPClient.errorDestination))
    }

    // MARK: - 하트비트 협상

    @Test("서버가 heart-beat을 0으로 답하면 보내지 않는다 (실서버가 0,0으로 답한다)")
    func stopsHeartbeatWhenServerDeclines() {
        #expect(stompOutgoingHeartbeat(clientCanSend: 10000, connectedHeader: "0,0") == 0)
        #expect(stompOutgoingHeartbeat(clientCanSend: 10000, connectedHeader: nil) == 0)
    }

    @Test("서버가 원하는 간격과 내가 보낼 수 있는 간격 중 큰 값으로 정한다")
    func negotiatesLongerInterval() {
        #expect(stompOutgoingHeartbeat(clientCanSend: 10000, connectedHeader: "0,5000") == 10000)
        #expect(stompOutgoingHeartbeat(clientCanSend: 10000, connectedHeader: "0,20000") == 20000)
    }

    @Test("내가 보낼 수 없다고 알렸으면 서버가 원해도 보내지 않는다")
    func neverSendsWhenClientDeclared0() {
        #expect(stompOutgoingHeartbeat(clientCanSend: 0, connectedHeader: "0,5000") == 0)
    }

    @Test("heart-beat 헤더가 망가져 있으면 보내지 않는다")
    func ignoresMalformedHeader() {
        #expect(stompOutgoingHeartbeat(clientCanSend: 10000, connectedHeader: "이상함") == 0)
        #expect(stompOutgoingHeartbeat(clientCanSend: 10000, connectedHeader: "0,") == 0)
    }

    @Test("백오프는 1·2·4·8·30초 뒤 30초로 고정된다")
    func backoffSchedule() {
        let schedule = (0 ... 5).map { STOMPClient.backoff(attempt: $0) }
        #expect(schedule == [.seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(30), .seconds(30)])
    }

    // MARK: - 앱 생명주기

    @Test("백그라운드에서 소켓을 정리하고 포그라운드 복귀 때 다시 붙는다")
    func reconnectsOnForeground() async throws {
        let factory = FakeChannelFactory()
        let client = makeClient(factory: factory)

        let stream = try await client.subscribe(to: "/topic/a")
        let events = EventCollector()
        let consumer = Task { for try await event in stream {
            await events.append(event)
        } }
        try await Task.sleep(for: .milliseconds(20))

        await client.applicationDidEnterBackground()
        #expect(await factory.channels[0].closeCount == 1)

        await client.applicationWillEnterForeground()
        try await Task.sleep(for: .milliseconds(50))

        #expect(factory.channels.count == 2)
        #expect(await factory.channels[1].roomSubscribes.count == 1)
        #expect(await events.events == [.resumed])

        consumer.cancel()
    }
}
