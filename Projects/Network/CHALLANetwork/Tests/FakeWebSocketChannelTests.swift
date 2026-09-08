@testable import CHALLANetwork
import Foundation
import Testing

/// 커밋 3~4의 `STOMPClient` 테스트가 전부 이 하니스 위에 서기 때문에, 하니스 자체를 먼저 검증한다.
@Suite("FakeWebSocketChannel")
struct FakeWebSocketChannelTests {

    @Test("push가 receive보다 먼저 와도 큐에 쌓였다가 순서대로 나온다")
    func queuesBeforeReceive() async throws {
        let channel = FakeWebSocketChannel()
        await channel.push("첫째")
        await channel.push("둘째")

        #expect(try await channel.receive() == .text("첫째"))
        #expect(try await channel.receive() == .text("둘째"))
    }

    @Test("기다리고 있던 receive를 나중의 push가 깨운다")
    func wakesWaitingReceive() async throws {
        let channel = FakeWebSocketChannel()
        let received = Task { try await channel.receive() }

        // receive가 대기 자리를 잡을 시간을 준다.
        try await Task.sleep(for: .milliseconds(20))
        await channel.push("깨어남")

        #expect(try await received.value == .text("깨어남"))
    }

    @Test("연결이 끊기면 기다리던 receive가 오류로 깨어난다")
    func failPropagatesToWaiter() async throws {
        let channel = FakeWebSocketChannel()
        let received = Task { try await channel.receive() }

        try await Task.sleep(for: .milliseconds(20))
        await channel.fail(STOMPError.notConnected)

        await #expect(throws: STOMPError.notConnected) { try await received.value }
    }

    @Test("보낸 프레임을 STOMP 명령별로 센다")
    func countsSentCommands() async throws {
        let channel = FakeWebSocketChannel()
        try await channel.send(.text(STOMPFrame(command: .connect, headers: ["host": "a"]).encoded()))
        try await channel.send(.text(STOMPFrame(command: .subscribe, headers: ["id": "sub-0"]).encoded()))
        try await channel.send(.text(STOMPFrame(command: .subscribe, headers: ["id": "sub-1"]).encoded()))
        try await channel.send(.text("\n")) // 하트비트는 세지 않는다

        #expect(await channel.sentCount(of: .connect) == 1)
        #expect(await channel.sentCount(of: .subscribe) == 2)
        #expect(await channel.sentText.count == 3)
    }

    @Test("open한 요청을 기록한다")
    func recordsOpenedRequest() async throws {
        let channel = FakeWebSocketChannel()
        var request = try URLRequest(url: #require(URL(string: "ws://a.com/api/v1/ws")))
        request.setValue("Bearer t", forHTTPHeaderField: "Authorization")
        await channel.open(request)

        #expect(await channel.openedRequests.count == 1)
        #expect(await channel.openedRequests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer t")
    }
}
