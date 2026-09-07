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
        /// REST로 확보한 연속 구간의 ID. 소켓으로 받은 한 건을 재연결 기준점으로 오인하지 않게 분리한다.
        public var historyAnchorIDs: Set<ChatMessageID> = []
        /// 빈 방도 최초 REST 조회를 마쳤는지 구분한다. 빈 방의 재연결은 anchor가 없어 끝까지 훑어야 한다.
        public var hasLoadedHistory = false
        /// 소켓이 붙어 있는지. 지금은 화면에 그리지 않고 상태로만 둔다.
        public var isRealtimeConnected = false
        /// 남이 보낸 새 메시지가 도착했다 — 맨 아래로 내려가는 버튼을 띄운다.
        /// 새 메시지가 왔다고 화면을 따라 내리지 않는다. 이전 대화를 읽는 중이면 방해가 된다.
        public var hasNewMessageBelow = false
        /// 목록의 맨 아래가 화면에 보이는지. 보고 있으면 새 메시지도 이미 눈에 들어와 버튼이 필요 없다.
        public var isAtBottom = true
        /// 구독을 다시 시도한 횟수. 화면을 열어 둔 동안만 유효하다.
        public var streamRetryCount = 0
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
            /// 목록 맨 아래가 화면에 들어오거나 벗어났다.
            case bottomVisibilityChanged(Bool)
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
        /// 구독이 안 됐거나 끊겼다. REST로 목록을 채우고 잠시 뒤 다시 시도한다.
        /// 얼럿은 띄우지 않는다 — 실시간만 없을 뿐 화면은 그대로 돈다.
        case subscribeFailed

        case chatsResponse(Result<ChatPage, ChatError>)
        /// 이전 페이지(더보기) 조회 결과 — 목록 위에 붙인다.
        case moreChatsResponse(Result<ChatPage, ChatError>)
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
    @Dependency(\.continuousClock) var clock
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

            case let .view(.bottomVisibilityChanged(isAtBottom)):
                state.isAtBottom = isAtBottom
                // 맨 아래까지 내려왔으면 안 읽은 것이 없다.
                if isAtBottom {
                    state.hasNewMessageBelow = false
                }
                return .none

            case .subscribed:
                state.isRealtimeConnected = true
                state.streamRetryCount = 0
                // 재연결이면 끊겨 있던 구간을 이 조회가 메운다.
                return loadHistory(&state)

            case .subscribeFailed:
                state.isRealtimeConnected = false
                return .merge(loadHistory(&state), retryStream(&state))

            case let .received(message):
                // 소켓으로 되돌아온 내 메시지는, 전송 응답에 chatId가 없어 로컬 id로 남아 있는
                // 같은 메시지를 대신한다. 과거 목록을 붙일 때는 이 흡수를 켜지 않는다.
                state.messages = ChatMessage.merged(
                    state.messages,
                    with: [message],
                    absorbingPendingSends: true
                )
                // 내 메시지가 되돌아온 것이거나 이미 맨 아래를 보고 있으면 버튼이 필요 없다.
                if !message.isMine(currentUserID: state.currentUserID), !state.isAtBottom {
                    state.hasNewMessageBelow = true
                }
                return .none

            case let .chatsResponse(.success(page)):
                state.isLoading = false
                // 교체가 아니라 병합이다 — 조회 중에 소켓으로 온 메시지를 덮어쓰면 안 된다.
                state.messages = ChatMessage.merged(state.messages, with: page.messages)
                if !page.anchorIDs.isEmpty {
                    state.historyAnchorIDs = page.anchorIDs
                }
                state.hasLoadedHistory = true
                // 이미 더 많이 읽었다면 다음 페이지를 뒤로 돌려 중복 조회하지 않는다.
                state.nextPage = max(state.nextPage, page.nextPage)
                state.hasMore = page.hasMore
                return .none

            case let .chatsResponse(.failure(error)):
                state.isLoading = false
                // 이미 보여줄 목록이 있으면(재연결 뒤 재조회 실패 등) 조용히 넘긴다.
                guard state.messages.isEmpty else { return .none }
                state.alert = Self.errorAlert(title: "채팅을 불러오지 못했어요", error: error)
                return .none

            case let .moreChatsResponse(.success(page)):
                state.isLoadingMore = false
                if !page.messages.isEmpty {
                    state.messages = ChatMessage.merged(state.messages, with: page.messages)
                    // 최초 페이지가 전부 매핑 탈락한 경우, 처음 확보한 REST 구간을 복구 기준으로 쓴다.
                    if state.historyAnchorIDs.isEmpty {
                        state.historyAnchorIDs = page.anchorIDs
                    }
                }
                state.nextPage = page.nextPage
                state.hasMore = page.hasMore
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
}

/// 리듀서 본문 길이를 줄이려고 이펙트를 뺐다. 접근 범위는 그대로다.
private extension ChatRoomFeature {

    // MARK: - Effects

    /// 구독을 먼저 확정하고 그 다음에 과거 목록을 부른다 — 백엔드가 정한 채팅 누락 방지 순서다.
    /// 구독 실패는 얼럿을 띄우지 않는다. 실시간만 없을 뿐 화면은 REST로 그대로 돈다.
    func start(_ state: inout State) -> Effect<Action> {
        guard !state.didStart else { return .none }
        state.didStart = true
        state.isLoading = true
        let roomID = state.roomID

        return .run { [observeChatsUseCase] send in
            let events: AsyncThrowingStream<ChatStreamEvent, any Error>
            do {
                events = try await observeChatsUseCase.run(roomID)
            } catch {
                await send(.subscribeFailed)
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
                // 정상 종료는 화면이 사라질 때뿐이라 알릴 것이 없다.
            } catch is CancellationError {
                return
            } catch {
                await send(.subscribeFailed)
            }
        }
        .cancellable(id: CancelID.stream, cancelInFlight: true)
    }

    /// 구독이 실패했으면 잠시 뒤 다시 시도한다.
    ///
    /// 소켓이 재연결 중일 때 화면에 들어오면 구독이 한 번 실패하는데, 재시도가 없으면
    /// 그 방문 내내 실시간 없이 REST로만 돈다 — 나갔다 들어와야 살아난다.
    /// `STOMPClient`의 자체 재연결은 도움이 안 된다. 구독이 아예 등록되지 않았기 때문이다.
    func retryStream(_ state: inout State) -> Effect<Action> {
        guard state.streamRetryCount < Const.maxStreamRetries else { return .none }
        state.streamRetryCount += 1
        state.didStart = false

        return .run { [clock] send in
            try await clock.sleep(for: Const.streamRetryDelay)
            await send(.view(.task))
        }
        .cancellable(id: CancelID.streamRetry, cancelInFlight: true)
    }

    /// 최신 페이지부터 기존 메시지와 겹치는 지점까지 부른다.
    ///
    /// 끊긴 사이에 한 페이지보다 많은 메시지가 생겨도 중간 구간을 놓치지 않는다.
    /// 기존 서버 메시지가 하나도 없는 첫 진입은 첫 페이지만 가져오고, 이후 과거 목록은 더보기로 받는다.
    /// `cancelInFlight`가 재연결이 몰아칠 때의 중복 조회를 합쳐 준다.
    func loadHistory(_ state: inout State) -> Effect<Action> {
        state.isLoading = true
        state.isLoadingMore = false
        let roomID = state.roomID
        let historyAnchorIDs = state.historyAnchorIDs
        let isInitialLoad = !state.hasLoadedHistory

        let request: Effect<Action> = .run { [fetchChatsUseCase] send in
            do {
                var recovered: [ChatMessage] = []
                var pageNumber = 0
                var lastPage = ChatPage(messages: [], nextPage: 1, hasMore: false)
                var latestPageIDs: Set<ChatMessageID> = []

                repeat {
                    let page = try await fetchChatsUseCase.run(roomID, pageNumber, Const.pageSize)
                    lastPage = page
                    if pageNumber == 0 {
                        latestPageIDs = page.anchorIDs
                    }
                    recovered.append(contentsOf: page.messages)

                    // 첫 진입은 최신 한 페이지만 받는다. 재연결은 기존 메시지와 이어졌거나
                    // 서버의 마지막 페이지에 닿았을 때 복구를 마친다.
                    let overlapsHistory = page.messages.contains { historyAnchorIDs.contains($0.id) }
                    guard !isInitialLoad, page.hasMore else {
                        break
                    }
                    // 비어 있던 방은 기준 ID가 없으므로 서버의 끝까지 확인한다.
                    guard historyAnchorIDs.isEmpty || !overlapsHistory else {
                        break
                    }
                    pageNumber = page.nextPage
                } while true

                await send(.chatsResponse(.success(ChatPage(
                    messages: recovered,
                    nextPage: lastPage.nextPage,
                    hasMore: lastPage.hasMore,
                    anchorIDs: latestPageIDs
                ))))
            } catch {
                guard let failure = Self.failure(error) else { return }
                await send(.chatsResponse(.failure(failure)))
            }
        }
        .cancellable(id: CancelID.history, cancelInFlight: true)

        return .merge(.cancel(id: CancelID.moreHistory), request)
    }

    /// 위로 스크롤해 맨 위에 닿으면 이전 페이지를 더 불러온다. 첫 로딩 중이거나 더 없으면 무시한다.
    func loadMore(_ state: inout State) -> Effect<Action> {
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
        .cancellable(id: CancelID.moreHistory, cancelInFlight: true)
    }

    /// 빈 메시지·전송 중 재탭은 무시한다. 로컬에서 만든 메시지를 맨 아래에 낙관적으로 덧붙이고 입력창을 비운다.
    func send(_ state: inout State) -> Effect<Action> {
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
    func confirmSent(_ state: inout State, id: ChatMessage.ID, chatID: Int64?) -> Effect<Action> {
        guard
            let chatID,
            let index = state.messages.firstIndex(where: { $0.id == id })
        else { return .none }

        let confirmed = state.messages.remove(at: index).promoted(toServerID: chatID)
        state.messages = ChatMessage.merged(state.messages, with: [confirmed])
        return .none
    }

    /// 화면을 벗어나 취소된 경우 nil을 반환한다(알릴 대상이 없다). 나머지는 ChatError로 바꾼다.
    static func failure(_ error: any Error) -> ChatError? {
        if error is CancellationError {
            return nil
        }
        return error as? ChatError ?? .unknown
    }

    static func errorAlert(title: String, error: ChatError) -> AlertState<Action.Alert> {
        AlertState {
            TextState(title)
        } actions: {
            ButtonState(role: .cancel) { TextState("확인") }
        } message: {
            TextState(error.userMessage)
        }
    }
}

/// 리듀서 본문 길이를 줄이려고 뺐다. 접근 범위(private)는 그대로다.
private extension ChatRoomFeature {

    private enum CancelID: Hashable {
        case stream
        case history
        case moreHistory
        case streamRetry
    }

    private enum Const {
        static let pageSize = 30
        /// 화면을 열어 둔 동안 구독을 다시 시도할 횟수. 서버가 죽었을 때 계속 두드리지 않게 막는다.
        static let maxStreamRetries = 3
        static let streamRetryDelay: Duration = .seconds(3)
    }
}
