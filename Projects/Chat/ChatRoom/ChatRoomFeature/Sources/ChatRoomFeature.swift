import ChatDomain
import ComposableArchitecture
import Foundation

/// 방 채팅 화면(개별 상세)
@Reducer
public struct ChatRoomFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {

        public let roomID: Int64
        /// 탑 내비게이션 타이틀.
        public let roomTitle: String
        /// 내 메시지(오른쪽 흰 버블) 판별용 — 응답의 userId와 비교한다.
        public let currentUserID: Int64
        /// 낙관적으로 덧붙이는 내 메시지의 표시 이름.
        public let currentUserNickname: String
        /// 인화 전에는 채팅 사진을 블러 처리한다.
        public let isPrinted: Bool

        public var messages: [ChatMessage] = []
        public var draft: String = ""
        public var isLoading = false
        public var isSending = false
        /// 이전(더 오래된) 페이지를 불러오는 중.
        public var isLoadingMore = false
        /// 더 불러올 이전 페이지가 있는지. 서버가 hasNext를 안 줘 "받은 수 == pageSize"로 가늠한다.
        public var hasMore = false
        /// 더보기로 다음에 불러올 페이지 번호(첫 페이지는 0).
        public var nextPage = 0
        /// 소켓이 붙어 있는지. 지금은 화면에 그리지 않고 상태로만 둔다.
        public var isRealtimeConnected = false
        /// 남이 보낸 새 메시지가 도착했다 — 맨 아래로 내려가는 버튼을 띄운다.
        /// 새 메시지가 왔다고 화면을 따라 내리지 않는다. 이전 대화를 읽는 중이면 방해가 된다.
        public var hasNewMessageBelow = false
        /// 진입 준비를 이미 했는지 — `.task`가 다시 불려도 구독이 둘이 되지 않게 막는다.
        public var didStart = false
        @Presents public var alert: AlertState<Action.Alert>?

        public init(
            roomID: Int64,
            roomTitle: String,
            currentUserID: Int64,
            currentUserNickname: String,
            isPrinted: Bool
        ) {
            self.roomID = roomID
            self.roomTitle = roomTitle
            self.currentUserID = currentUserID
            self.currentUserNickname = currentUserNickname
            self.isPrinted = isPrinted
        }
    }

    // MARK: - Action

    public enum Action: ViewAction, Sendable {

        public enum ViewAction: Sendable {
            case task
            case backButtonTapped
            case draftChanged(String)
            case sendTapped
            /// 목록 맨 위에 닿음 — 이전 메시지를 더 불러온다.
            case reachedTop
            /// 새 메시지 버튼을 눌렀다 — 맨 아래로 내려간다.
            case scrollToBottomTapped
        }

        case view(ViewAction)

        /// App에만 알린다. 화면을 닫는 것은 App이 한다 (규칙 3).
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case closeRequested
        }

        case delegate(Delegate)

        /// 구독이 확정됐다(첫 연결·재연결 공통). 이 다음에야 과거 목록을 부른다 —
        /// 순서가 뒤집히면 조회와 구독 사이에 온 메시지를 놓친다.
        case subscribed
        /// 소켓으로 받은 메시지 한 건.
        case received(ChatMessage)
        /// 소켓을 포기했다. 조회·전송은 REST로 계속되므로 얼럿은 띄우지 않는다.
        case streamEnded

        case chatsResponse(Result<[ChatMessage], ChatError>)
        /// 이전 페이지(더보기) 조회 결과 — 목록 위에 붙인다.
        case moreChatsResponse(Result<[ChatMessage], ChatError>)
        /// 전송 결과. 성공하면 서버가 준 chatId로 낙관적 메시지를 확정한다.
        case sendResponse(id: ChatMessage.ID, Result<Int64?, ChatError>)

        public enum Alert: Equatable, Sendable {}

        case alert(PresentationAction<Alert>)
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.fetchChatsUseCase) var fetchChatsUseCase
    @Dependency(\.sendChatUseCase) var sendChatUseCase
    @Dependency(\.observeChatsUseCase) var observeChatsUseCase
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.task):
                return start(&state)

            case .view(.backButtonTapped):
                return .send(.delegate(.closeRequested))

            case let .view(.draftChanged(text)):
                state.draft = text
                return .none

            case .view(.sendTapped):
                return send(&state)

            case .view(.reachedTop):
                return loadMore(&state)

            case .view(.scrollToBottomTapped):
                state.hasNewMessageBelow = false
                return .none

            case .subscribed:
                state.isRealtimeConnected = true
                // 재연결이면 끊겨 있던 구간을 이 조회가 메운다.
                return loadHistory(&state)

            case .streamEnded:
                state.isRealtimeConnected = false
                return loadHistory(&state)

            case let .received(message):
                state.messages = ChatMessage.merged(state.messages, with: [message])
                // 내 메시지가 되돌아온 것이면 이미 화면이 맨 아래에 있다.
                if !message.isMine(currentUserID: state.currentUserID) {
                    state.hasNewMessageBelow = true
                }
                return .none

            case let .chatsResponse(.success(page)):
                state.isLoading = false
                // 교체가 아니라 병합이다 — 조회 중에 소켓으로 온 메시지를 덮어쓰면 안 된다.
                state.messages = ChatMessage.merged(state.messages, with: page)
                // 페이지 상태는 첫 조회에서만 정한다. 재연결 재조회가 이미 불러온 이전 페이지를 날리면 안 된다.
                if state.nextPage == 0 {
                    state.nextPage = 1
                    state.hasMore = page.count >= Const.pageSize
                }
                return .none

            case let .chatsResponse(.failure(error)):
                state.isLoading = false
                // 이미 보여줄 목록이 있으면(재연결 뒤 재조회 실패 등) 조용히 넘긴다.
                guard state.messages.isEmpty else { return .none }
                state.alert = Self.errorAlert(title: "채팅을 불러오지 못했어요", error: error)
                return .none

            case let .moreChatsResponse(.success(older)):
                state.isLoadingMore = false
                guard !older.isEmpty else {
                    state.hasMore = false
                    return .none
                }
                state.messages = ChatMessage.merged(state.messages, with: older)
                state.nextPage += 1
                state.hasMore = older.count >= Const.pageSize
                return .none

            case .moreChatsResponse(.failure):
                // 더보기 실패는 얼럿 없이 둔다 — 다시 위로 당기면 재시도.
                state.isLoadingMore = false
                return .none

            case let .sendResponse(id, .success(chatID)):
                state.isSending = false
                return confirmSent(&state, id: id, chatID: chatID)

            case let .sendResponse(id, .failure(error)):
                state.isSending = false
                state.messages.removeAll { $0.id == id } // 낙관적으로 덧붙인 메시지 되돌리기
                state.alert = Self.errorAlert(title: "메시지를 보내지 못했어요", error: error)
                return .none

            case .delegate, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    // MARK: - Effects

    /// 구독을 먼저 확정하고 그 다음에 과거 목록을 부른다 — 백엔드가 정한 채팅 누락 방지 순서다.
    /// 구독 실패는 얼럿을 띄우지 않는다. 실시간만 없을 뿐 화면은 REST로 그대로 돈다.
    private func start(_ state: inout State) -> Effect<Action> {
        guard !state.didStart else { return .none }
        state.didStart = true
        state.isLoading = true
        let roomID = state.roomID

        return .run { [observeChatsUseCase] send in
            let events: AsyncThrowingStream<ChatStreamEvent, any Error>
            do {
                events = try await observeChatsUseCase.run(roomID)
            } catch {
                await send(.streamEnded)
                return
            }
            await send(.subscribed)

            do {
                for try await event in events {
                    switch event {
                    case let .message(message):
                        await send(.received(message))
                    case .resumed:
                        await send(.subscribed)
                    }
                }
                await send(.streamEnded)
            } catch is CancellationError {
                return
            } catch {
                await send(.streamEnded)
            }
        }
        .cancellable(id: CancelID.stream, cancelInFlight: true)
    }

    /// 첫 페이지를 다시 부른다. `cancelInFlight`가 재연결이 몰아칠 때의 중복 조회를 합쳐 준다.
    private func loadHistory(_ state: inout State) -> Effect<Action> {
        state.isLoading = true
        let roomID = state.roomID

        return .run { [fetchChatsUseCase] send in
            do {
                let messages = try await fetchChatsUseCase.run(roomID, 0, Const.pageSize)
                await send(.chatsResponse(.success(messages)))
            } catch {
                guard let failure = Self.failure(error) else { return }
                await send(.chatsResponse(.failure(failure)))
            }
        }
        .cancellable(id: CancelID.history, cancelInFlight: true)
    }

    /// 위로 스크롤해 맨 위에 닿으면 이전 페이지를 더 불러온다. 첫 로딩 중이거나 더 없으면 무시한다.
    private func loadMore(_ state: inout State) -> Effect<Action> {
        guard state.hasMore, !state.isLoadingMore, !state.isLoading else { return .none }
        state.isLoadingMore = true
        let roomID = state.roomID
        let page = state.nextPage

        return .run { [fetchChatsUseCase] send in
            do {
                let older = try await fetchChatsUseCase.run(roomID, page, Const.pageSize)
                await send(.moreChatsResponse(.success(older)))
            } catch {
                guard let failure = Self.failure(error) else { return }
                await send(.moreChatsResponse(.failure(failure)))
            }
        }
    }

    /// 빈 메시지·전송 중 재탭은 무시한다. 로컬에서 만든 메시지를 맨 아래에 낙관적으로 덧붙이고 입력창을 비운다.
    private func send(_ state: inout State) -> Effect<Action> {
        let content = state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !state.isSending else { return .none }

        let message = ChatMessage(
            id: .local(uuid()),
            kind: .text,
            content: content,
            authorID: state.currentUserID,
            authorName: state.currentUserNickname,
            createdAt: date.now
        )
        state.isSending = true
        state.draft = ""
        state.messages = ChatMessage.merged(state.messages, with: [message])
        // 내가 보낸 것은 화면이 따라 내려가므로 버튼을 남길 이유가 없다.
        state.hasNewMessageBelow = false
        let roomID = state.roomID

        return .run { [sendChatUseCase] send in
            do {
                let chatID = try await sendChatUseCase.run(roomID, nil, content)
                await send(.sendResponse(id: message.id, .success(chatID)))
            } catch {
                guard let failure = Self.failure(error) else { return }
                await send(.sendResponse(id: message.id, .failure(failure)))
            }
        }
    }

    /// 서버가 준 chatId로 낙관적 메시지를 확정한다.
    /// 확정해 두면 소켓으로 되돌아온 같은 메시지가 id로 합쳐져 목록에 두 번 뜨지 않는다.
    /// chatId가 없으면(서버가 안 준 경우) 로컬 id인 채로 두고, 소켓 메시지는 별개 항목으로 들어온다.
    private func confirmSent(_ state: inout State, id: ChatMessage.ID, chatID: Int64?) -> Effect<Action> {
        guard
            let chatID,
            let index = state.messages.firstIndex(where: { $0.id == id })
        else { return .none }

        let confirmed = state.messages.remove(at: index).promoted(toServerID: chatID)
        state.messages = ChatMessage.merged(state.messages, with: [confirmed])
        return .none
    }

    /// 화면을 벗어나 취소된 경우 nil을 반환한다(알릴 대상이 없다). 나머지는 ChatError로 바꾼다.
    private static func failure(_ error: any Error) -> ChatError? {
        if error is CancellationError {
            return nil
        }
        return error as? ChatError ?? .unknown
    }

    private static func errorAlert(title: String, error: ChatError) -> AlertState<Action.Alert> {
        AlertState {
            TextState(title)
        } actions: {
            ButtonState(role: .cancel) { TextState("확인") }
        } message: {
            TextState(error.userMessage)
        }
    }

    private enum CancelID: Hashable {
        case stream
        case history
    }

    private enum Const {
        static let pageSize = 30
    }
}
