import ChatDomain
import ChatRoomFeature
import ComposableArchitecture
import Foundation
import Testing

/// 소켓으로 들어오는 이벤트를 화면이 어떻게 다루는지 — 구독 순서·병합·새 메시지 버튼.
@MainActor
@Suite("ChatRoomFeature — 실시간 수신")
struct ChatRoomRealtimeTests {

    @Test("구독이 확정된 뒤에야 과거 목록을 부른다 (그 사이 메시지를 놓치지 않게)")
    func requestsHistoryOnlyAfterSubscribed() async {
        let (stream, continuation) = AsyncThrowingStream<ChatStreamEvent, any Error>.makeStream()
        let store = makeChatStore(
            messages: { _, _, _ in [Fixture.message(chatID: 1, content: "과거")] },
            observe: { _ in stream }
        )

        await store.send(.view(.task)) {
            $0.didStart = true
            $0.isLoading = true
        }
        // 순서가 곧 계약이다 — subscribed가 먼저 오지 않으면 이 단언이 깨진다.
        await store.receive(\.subscribed) { $0.isRealtimeConnected = true }
        await store.receive(\.chatsResponse.success) {
            $0.isLoading = false
            $0.messages = [Fixture.message(chatID: 1, content: "과거")]
            $0.nextPage = 1
        }

        continuation.finish()
        await store.receive(\.streamEnded) {
            $0.isRealtimeConnected = false
            $0.isLoading = true
        }
        await store.receive(\.chatsResponse.success) { $0.isLoading = false }
    }

    @Test("소켓으로 온 메시지를 목록에 더한다")
    func appendsMessageFromSocket() async {
        let (stream, continuation) = AsyncThrowingStream<ChatStreamEvent, any Error>.makeStream()
        let store = makeChatStore(observe: { _ in stream })
        store.exhaustivity = .off

        await store.send(.view(.task))
        let incoming = Fixture.message(chatID: 9, content: "왔다", createdAt: Date(timeIntervalSince1970: 5000))
        continuation.yield(.message(incoming))
        await store.receive(\.received)

        #expect(store.state.messages == [incoming])

        continuation.finish()
        await store.finish()
    }

    @Test("내가 보낸 메시지가 소켓으로 되돌아와도 목록에 한 번만 보인다")
    func socketEchoOfOwnMessageIsDeduped() async {
        let (stream, continuation) = AsyncThrowingStream<ChatStreamEvent, any Error>.makeStream()
        let store = makeChatStore(send: { _, _, _ in 42 }, observe: { _ in stream })
        store.exhaustivity = .off

        await store.send(.view(.task))
        await store.send(.view(.draftChanged("보냄")))
        await store.send(.view(.sendTapped))
        await store.receive(\.sendResponse)

        // 서버가 같은 메시지를 브로드캐스트한다 — 확정된 id와 같으므로 합쳐진다.
        continuation.yield(.message(Fixture.optimistic(content: "보냄").promoted(toServerID: 42)))
        await store.receive(\.received)

        #expect(store.state.messages.count == 1)
        #expect(store.state.messages.first?.id == .server(42))

        continuation.finish()
        await store.finish()
    }

    @Test("남이 보낸 메시지가 오면 화면을 내리지 않고 '맨 아래로' 버튼만 띄운다")
    func showsNewMessageButtonForOthers() async {
        let (stream, continuation) = AsyncThrowingStream<ChatStreamEvent, any Error>.makeStream()
        let store = makeChatStore(observe: { _ in stream })
        store.exhaustivity = .off

        await store.send(.view(.task))
        continuation.yield(.message(Fixture.message(chatID: 9, content: "왔다")))
        await store.receive(\.received)

        #expect(store.state.hasNewMessageBelow)

        await store.send(.view(.scrollToBottomTapped))
        #expect(store.state.hasNewMessageBelow == false)

        continuation.finish()
        await store.finish()
    }

    @Test("내가 보낸 메시지가 소켓으로 되돌아온 것에는 버튼을 띄우지 않는다")
    func doesNotShowButtonForOwnEcho() async {
        let (stream, continuation) = AsyncThrowingStream<ChatStreamEvent, any Error>.makeStream()
        let store = makeChatStore(observe: { _ in stream })
        store.exhaustivity = .off

        await store.send(.view(.task))
        continuation.yield(.message(Fixture.message(
            chatID: 9,
            content: "내 것",
            authorID: Fixture.currentUserID,
            author: Fixture.currentUserNickname
        )))
        await store.receive(\.received)

        #expect(store.state.hasNewMessageBelow == false)

        continuation.finish()
        await store.finish()
    }

    @Test("메시지를 보내면 버튼이 사라진다 (화면이 맨 아래로 따라간다)")
    func sendingClearsNewMessageButton() async {
        let (stream, continuation) = AsyncThrowingStream<ChatStreamEvent, any Error>.makeStream()
        let store = makeChatStore(send: { _, _, _ in 42 }, observe: { _ in stream })
        store.exhaustivity = .off

        await store.send(.view(.task))
        continuation.yield(.message(Fixture.message(chatID: 9, content: "왔다")))
        await store.receive(\.received)
        #expect(store.state.hasNewMessageBelow)

        await store.send(.view(.draftChanged("보냄")))
        await store.send(.view(.sendTapped))
        #expect(store.state.hasNewMessageBelow == false)

        await store.receive(\.sendResponse)
        continuation.finish()
        await store.finish()
    }

    @Test("재연결되면 과거 목록을 다시 불러 끊겨 있던 구간을 메운다")
    func refetchesHistoryOnResume() async {
        let (stream, continuation) = AsyncThrowingStream<ChatStreamEvent, any Error>.makeStream()
        let missed = Fixture.message(chatID: 3, content: "끊긴 사이에 온 것")
        let store = makeChatStore(messages: { _, _, _ in [missed] }, observe: { _ in stream })
        store.exhaustivity = .off

        await store.send(.view(.task))
        await store.receive(\.subscribed)
        await store.receive(\.chatsResponse.success)

        continuation.yield(.resumed)
        await store.receive(\.subscribed)
        await store.receive(\.chatsResponse.success)

        #expect(store.state.messages == [missed])
        // 재조회가 이미 불러온 페이지 상태를 되돌리지 않는다.
        #expect(store.state.nextPage == 1)

        continuation.finish()
        await store.finish()
    }
}
