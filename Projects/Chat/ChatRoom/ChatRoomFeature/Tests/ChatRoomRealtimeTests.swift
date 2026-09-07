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
            $0.historyAnchorIDs = [.server(1)]
            $0.hasLoadedHistory = true
        }

        // 스트림이 정상적으로 끝나는 것은 화면이 사라질 때뿐이라 아무 액션도 내지 않는다.
        continuation.finish()
        await store.finish()
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
        // 이전 대화를 읽는 중 — 맨 아래를 벗어나 있어야 버튼이 의미가 있다.
        await store.send(.view(.bottomVisibilityChanged(false)))
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
        await store.send(.view(.bottomVisibilityChanged(false)))
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

    @Test("재연결 사이 30건을 초과해도 기존 목록과 겹칠 때까지 조회한다")
    func refetchesUntilHistoryOverlapsAfterResume() async {
        let (stream, continuation) = AsyncThrowingStream<ChatStreamEvent, any Error>.makeStream()
        let old = (1 ... 10).map { Fixture.message(chatID: Int64($0), content: "old-\($0)") }
        let newest = (12 ... 41).map { Fixture.message(chatID: Int64($0), content: "new-\($0)") }
        let remaining = [Fixture.message(chatID: 11, content: "new-11")] + old
        let history = ReconnectHistoryStub(initial: old, recovery: [newest, remaining])
        let store = makeChatStore(
            messages: { _, page, _ in try await history.page(page) },
            observe: { _ in stream }
        )
        store.exhaustivity = .off

        await store.send(.view(.task))
        await store.receive(\.subscribed)
        await store.receive(\.chatsResponse.success)

        continuation.yield(.resumed)
        await store.receive(\.subscribed)
        await store.receive(\.chatsResponse.success)

        #expect(store.state.messages.count == 41)
        #expect(await history.requests == [0, 0, 1])
        #expect(store.state.hasMore == false)
        #expect(store.state.nextPage == 2)

        continuation.finish()
        await store.finish()
    }

    @Test("비어 있던 방은 재연결 때 기준점이 없어도 서버 끝까지 복구한다")
    func refetchesToEndAfterInitiallyEmptyHistory() async {
        let (stream, continuation) = AsyncThrowingStream<ChatStreamEvent, any Error>.makeStream()
        let newest = (1 ... 30).map { Fixture.message(chatID: Int64($0), content: "new-\($0)") }
        let oldest = [Fixture.message(chatID: 31, content: "new-31")]
        let history = ReconnectPageStub(
            initial: ChatPage(messages: [], nextPage: 1, hasMore: false),
            recovery: [
                ChatPage(messages: newest, nextPage: 1, hasMore: true),
                ChatPage(messages: oldest, nextPage: 2, hasMore: false)
            ]
        )
        let store = makeChatStore(pages: { _, page, _ in try await history.page(page) }, observe: { _ in stream })
        store.exhaustivity = .off

        await store.send(.view(.task))
        await store.receive(\.subscribed)
        await store.receive(\.chatsResponse.success)
        continuation.yield(.resumed)
        await store.receive(\.subscribed)
        await store.receive(\.chatsResponse.success)

        #expect(store.state.messages.count == 31)
        #expect(await history.requests == [0, 0, 1])

        continuation.finish()
        await store.finish()
    }

    @Test("재연결 최신 페이지가 전부 매핑 탈락해도 기존 복구 기준을 보존한다")
    func preservesAnchorWhenLatestMappedPageIsEmpty() async {
        let (stream, continuation) = AsyncThrowingStream<ChatStreamEvent, any Error>.makeStream()
        let old = Fixture.message(chatID: 1, content: "기준")
        let history = ReconnectPageStub(
            initial: ChatPage(messages: [old], nextPage: 1, hasMore: false),
            recovery: [
                ChatPage(messages: [], nextPage: 1, hasMore: true),
                ChatPage(messages: [old], nextPage: 2, hasMore: false)
            ]
        )
        let store = makeChatStore(pages: { _, page, _ in try await history.page(page) }, observe: { _ in stream })
        store.exhaustivity = .off

        await store.send(.view(.task))
        await store.receive(\.subscribed)
        await store.receive(\.chatsResponse.success)
        continuation.yield(.resumed)
        await store.receive(\.subscribed)
        await store.receive(\.chatsResponse.success)

        #expect(store.state.historyAnchorIDs == [old.id])
        #expect(await history.requests == [0, 0, 1])

        continuation.finish()
        await store.finish()
    }

    // MARK: - 구독 실패

    @Test("구독이 안 되면 얼럿 없이 REST로만 채운다")
    func fallsBackToRESTWhenSubscribeFails() async {
        let store = makeChatStore(
            messages: { _, _, _ in [Fixture.message(chatID: 1, content: "과거")] },
            observe: { _ in throw ChatError.network }
        )
        store.exhaustivity = .off

        await store.send(.view(.task))
        await store.receive(\.subscribeFailed)
        await store.receive(\.chatsResponse.success)

        #expect(store.state.messages.count == 1)
        #expect(store.state.alert == nil)
        #expect(store.state.isRealtimeConnected == false)

        await store.finish()
    }

    @Test("구독 실패는 정해진 횟수만큼 다시 시도한다")
    func retriesSubscribeBoundedNumberOfTimes() async {
        let attempts = AttemptCounter()
        let store = makeChatStore(observe: { _ in
            await attempts.record()
            throw ChatError.network
        })
        store.exhaustivity = .off

        await store.send(.view(.task))
        await store.finish()

        // 첫 시도 + 재시도 상한(3회).
        #expect(await attempts.count == 4)
    }

    // MARK: - 새 메시지 버튼

    @Test("맨 아래를 보고 있으면 새 메시지가 와도 버튼을 띄우지 않는다")
    func noButtonWhileAtBottom() async {
        let (stream, continuation) = AsyncThrowingStream<ChatStreamEvent, any Error>.makeStream()
        let store = makeChatStore(observe: { _ in stream })
        store.exhaustivity = .off

        await store.send(.view(.task))
        await store.send(.view(.bottomVisibilityChanged(true)))
        continuation.yield(.message(Fixture.message(chatID: 9, content: "왔다")))
        await store.receive(\.received)

        #expect(store.state.hasNewMessageBelow == false)

        continuation.finish()
        await store.finish()
    }

    @Test("맨 아래까지 내려오면 떠 있던 버튼이 사라진다")
    func scrollingToBottomClearsButton() async {
        let (stream, continuation) = AsyncThrowingStream<ChatStreamEvent, any Error>.makeStream()
        let store = makeChatStore(observe: { _ in stream })
        store.exhaustivity = .off

        await store.send(.view(.task))
        await store.send(.view(.bottomVisibilityChanged(false)))
        continuation.yield(.message(Fixture.message(chatID: 9, content: "왔다")))
        await store.receive(\.received)
        #expect(store.state.hasNewMessageBelow)

        await store.send(.view(.bottomVisibilityChanged(true)))
        #expect(store.state.hasNewMessageBelow == false)

        continuation.finish()
        await store.finish()
    }
}

/// 구독 시도 횟수를 센다.
private actor AttemptCounter {
    private(set) var count = 0
    func record() {
        count += 1
    }
}

private actor ReconnectHistoryStub {
    private let initial: [ChatMessage]
    private let recovery: [[ChatMessage]]
    private var didServeInitial = false
    private(set) var requests: [Int] = []

    init(initial: [ChatMessage], recovery: [[ChatMessage]]) {
        self.initial = initial
        self.recovery = recovery
    }

    func page(_ number: Int) throws -> [ChatMessage] {
        requests.append(number)
        if !didServeInitial {
            didServeInitial = true
            return initial
        }
        guard recovery.indices.contains(number) else { return [] }
        return recovery[number]
    }
}

private actor ReconnectPageStub {
    private let initial: ChatPage
    private let recovery: [ChatPage]
    private var didServeInitial = false
    private(set) var requests: [Int] = []

    init(initial: ChatPage, recovery: [ChatPage]) {
        self.initial = initial
        self.recovery = recovery
    }

    func page(_ number: Int) throws -> ChatPage {
        requests.append(number)
        if !didServeInitial {
            didServeInitial = true
            return initial
        }
        guard recovery.indices.contains(number) else {
            return ChatPage(messages: [], nextPage: number + 1, hasMore: false)
        }
        return recovery[number]
    }
}
