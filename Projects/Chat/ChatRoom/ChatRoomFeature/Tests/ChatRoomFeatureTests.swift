import ChatDomain
import ChatRoomFeature
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite("ChatRoomFeature")
struct ChatRoomFeatureTests {

    @Test("진입하면 메시지를 받아 시간 오름차순(최신이 아래)으로 채운다")
    func loadsOnAppearSortedAscending() async {
        // 서버가 최신 먼저 내려줘도 화면은 오래된 것이 위, 최신이 아래여야 한다.
        let older = Fixture.message(id: UUID(1), content: "먼저", createdAt: Date(timeIntervalSince1970: 1000))
        let newer = Fixture.message(id: UUID(2), content: "나중", createdAt: Date(timeIntervalSince1970: 2000))
        let store = makeChatStore(messages: { roomID, _, _ in
            #expect(roomID == Fixture.roomID)
            return [newer, older]
        })

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.chatsResponse.success) {
            $0.isLoading = false
            $0.messages = [older, newer]
            $0.nextPage = 1
            // 2개(< pageSize)만 왔으니 더 없음.
        }
    }

    @Test("맨 위에 닿으면 이전 페이지를 불러와 위에 붙인다")
    func loadsMoreOnReachTop() async {
        // 첫 페이지를 pageSize(30)만큼 꽉 채워 받아 hasMore=true가 되게 한다.
        let page0 = (1 ... 30).map { index in
            Fixture.message(content: "p0-\(index)", createdAt: Date(timeIntervalSince1970: TimeInterval(2000 + index)))
        }
        let page1 = (1 ... 30).map { index in
            Fixture.message(content: "p1-\(index)", createdAt: Date(timeIntervalSince1970: TimeInterval(1000 + index)))
        }
        let store = makeChatStore(messages: { _, page, _ in page == 0 ? page0 : page1 })

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.chatsResponse.success) {
            $0.isLoading = false
            $0.messages = page0.sorted { $0.createdAt < $1.createdAt }
            $0.nextPage = 1
            $0.hasMore = true
        }

        await store.send(.view(.reachedTop)) { $0.isLoadingMore = true }
        await store.receive(\.moreChatsResponse.success) {
            $0.isLoadingMore = false
            // 이전 페이지(더 오래됨)가 위에 붙는다.
            $0.messages = (page1 + page0).sorted { $0.createdAt < $1.createdAt }
            $0.nextPage = 2
            $0.hasMore = true
        }
    }

    @Test("더 없으면(hasMore=false) 맨 위에 닿아도 아무 일도 하지 않는다")
    func reachTopDoesNothingWhenNoMore() async {
        let one = Fixture.message(content: "하나")
        let store = makeChatStore(messages: { _, _, _ in [one] })

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.chatsResponse.success) {
            $0.isLoading = false
            $0.messages = [one]
            $0.nextPage = 1
        }

        // 1개(< pageSize)라 hasMore=false → 더보기 무시.
        await store.send(.view(.reachedTop))
    }

    @Test("조회에 실패하면 얼럿을 띄운다")
    func showsAlertOnLoadFailure() async {
        let store = makeChatStore(messages: { _, _, _ in throw ChatError.network })

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.chatsResponse.failure) {
            $0.isLoading = false
            $0.alert = AlertState {
                TextState("채팅을 불러오지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(ChatError.network.userMessage)
            }
        }
    }

    @Test("메시지를 보내면 낙관적으로 맨 아래에 덧붙이고 입력창을 비운다")
    func sendAppendsMessageOptimistically() async {
        let store = makeChatStore(send: { roomID, photoID, content in
            #expect(roomID == Fixture.roomID)
            #expect(photoID == nil)
            #expect(content == "보냄")
        })
        // makeChatStore가 uuid=.incrementing, date=Fixture.sendDate로 고정한다.
        let optimistic = ChatMessage(
            id: UUID(0),
            kind: .text,
            content: "보냄",
            authorName: Fixture.currentUserNickname,
            createdAt: Fixture.sendDate
        )

        await store.send(.view(.draftChanged("보냄"))) { $0.draft = "보냄" }
        await store.send(.view(.sendTapped)) {
            $0.isSending = true
            $0.draft = ""
            $0.messages = [optimistic]
        }
        await store.receive(\.sendResponse) {
            $0.isSending = false
        }
    }

    @Test("전송이 실패하면 낙관적으로 덧붙인 메시지를 되돌리고 얼럿을 띄운다")
    func rollsBackOnSendFailure() async {
        let store = makeChatStore(send: { _, _, _ in throw ChatError.network })
        let optimistic = ChatMessage(
            id: UUID(0),
            kind: .text,
            content: "보냄",
            authorName: Fixture.currentUserNickname,
            createdAt: Fixture.sendDate
        )

        await store.send(.view(.draftChanged("보냄"))) { $0.draft = "보냄" }
        await store.send(.view(.sendTapped)) {
            $0.isSending = true
            $0.draft = ""
            $0.messages = [optimistic]
        }
        await store.receive(\.sendResponse) {
            $0.isSending = false
            $0.messages = []
            $0.alert = AlertState {
                TextState("메시지를 보내지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(ChatError.network.userMessage)
            }
        }
    }

    @Test("공백뿐인 메시지는 보내지 않는다")
    func ignoresBlankMessage() async {
        let store = makeChatStore()

        await store.send(.view(.draftChanged("   "))) { $0.draft = "   " }
        await store.send(.view(.sendTapped))
    }

    @Test("뒤로가기는 닫아 달라고 알리기만 한다")
    func requestsCloseOnBack() async {
        let store = makeChatStore()

        await store.send(.view(.backButtonTapped))
        await store.receive(\.delegate.closeRequested)
    }
}
