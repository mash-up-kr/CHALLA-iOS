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
        /// 내 메시지(오른쪽 흰 버블) 판별용 — 응답의 userName과 비교한다.
        public let currentUserNickname: String

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
        @Presents public var alert: AlertState<Action.Alert>?

        public init(roomID: Int64, roomTitle: String, currentUserNickname: String) {
            self.roomID = roomID
            self.roomTitle = roomTitle
            self.currentUserNickname = currentUserNickname
        }
    }

    // MARK: - Action

    public enum Action: ViewAction, Sendable {

        public enum ViewAction: Sendable {
            case onAppear
            case backButtonTapped
            case draftChanged(String)
            case sendTapped
            /// 목록 맨 위에 닿음 — 이전 메시지를 더 불러온다.
            case reachedTop
        }

        case view(ViewAction)

        /// App에만 알린다. 화면을 닫는 것은 App이 한다 (규칙 3).
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case closeRequested
        }

        case delegate(Delegate)

        case chatsResponse(Result<[ChatMessage], ChatError>)
        /// 이전 페이지(더보기) 조회 결과 — 목록 위에 붙인다.
        case moreChatsResponse(Result<[ChatMessage], ChatError>)
        /// 전송 결과. `id`는 낙관적으로 덧붙인 메시지 — 실패하면 그 메시지를 되돌린다.
        case sendResponse(id: UUID, Result<Void, ChatError>)

        public enum Alert: Equatable, Sendable {}

        case alert(PresentationAction<Alert>)
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.fetchChatsUseCase) var fetchChatsUseCase
    @Dependency(\.sendChatUseCase) var sendChatUseCase
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.onAppear):
                return load(&state)

            case .view(.backButtonTapped):
                return .send(.delegate(.closeRequested))

            case let .view(.draftChanged(text)):
                state.draft = text
                return .none

            case .view(.sendTapped):
                return send(&state)

            case .view(.reachedTop):
                return loadMore(&state)

            case let .chatsResponse(.success(messages)):
                state.isLoading = false
                // 최신 메시지가 맨 아래에 오도록 시간 오름차순으로 정렬한다(서버 정렬 순서에 의존하지 않는다).
                state.messages = messages.sorted { $0.createdAt < $1.createdAt }
                state.nextPage = 1
                // 한 페이지를 꽉 채워 받았으면 이전 페이지가 더 있을 수 있다.
                state.hasMore = messages.count >= Const.pageSize
                return .none

            case let .chatsResponse(.failure(error)):
                state.isLoading = false
                state.alert = Self.errorAlert(title: "채팅을 불러오지 못했어요", error: error)
                return .none

            case let .moreChatsResponse(.success(older)):
                state.isLoadingMore = false
                guard !older.isEmpty else {
                    state.hasMore = false
                    return .none
                }
                // 이전 메시지를 위에 붙이고 전체를 시간순으로 정렬한다.
                state.messages = (older + state.messages).sorted { $0.createdAt < $1.createdAt }
                state.nextPage += 1
                state.hasMore = older.count >= Const.pageSize
                return .none

            case .moreChatsResponse(.failure):
                // 더보기 실패는 얼럿 없이 둔다 — 다시 위로 당기면 재시도.
                state.isLoadingMore = false
                return .none

            case .sendResponse(_, .success):
                // 낙관적으로 덧붙인 메시지를 그대로 확정한다(재조회 없음).
                state.isSending = false
                return .none

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

    private func load(_ state: inout State) -> Effect<Action> {
        guard !state.isLoading else { return .none }
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
    /// 성공하면 그대로 두고, 실패하면 그 메시지를 되돌린 뒤 얼럿을 띄운다.
    private func send(_ state: inout State) -> Effect<Action> {
        let content = state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !state.isSending else { return .none }

        let message = ChatMessage(
            id: uuid(),
            kind: .text,
            content: content,
            authorName: state.currentUserNickname,
            createdAt: date.now
        )
        state.isSending = true
        state.draft = ""
        state.messages.append(message)
        let roomID = state.roomID

        return .run { [sendChatUseCase] send in
            do {
                try await sendChatUseCase.run(roomID, nil, content)
                await send(.sendResponse(id: message.id, .success(())))
            } catch {
                guard let failure = Self.failure(error) else { return }
                await send(.sendResponse(id: message.id, .failure(failure)))
            }
        }
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

    private enum Const {
        static let pageSize = 30
    }
}
