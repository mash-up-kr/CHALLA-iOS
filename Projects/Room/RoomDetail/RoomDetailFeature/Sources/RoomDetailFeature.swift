import ComposableArchitecture
import Foundation
import RoomDomain

/// 방 상세 화면. 홈에서 받은 `Room`으로 제목·그리드를 즉시 그리고,
/// 초대 코드·참여자는 진입 후 조회해 채운다. 화면 전환은 전부 `delegate`로 App에 알린다.
@Reducer
public struct RoomDetailFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        /// 홈에서 받은 방. 이 값 덕에 첫 프레임부터 제목·슬롯 그리드가 그려진다.
        public var room: Room
        /// 상세 조회 결과 (초대 코드·참여자). 채워지기 전에는 아바타 자리만 비워 둔다.
        public var detail: RoomDetail?
        public var detailLoad: LoadState = .notRequested
        /// 아바타 탭으로 여는 초대 코드 팝오버.
        public var isInvitePopoverPresented = false

        public init(room: Room) {
            self.room = room
        }
    }

    /// 조회가 안 끝난 것과 실패한 것을 구분한다 — 실패했을 때만 팝오버가 재시도를 건다.
    public enum LoadState: Equatable, Sendable {
        case notRequested
        case loading
        case loaded
        case failed
    }

    // MARK: - Action

    public enum Action: BindableAction, ViewAction, Sendable {
        case view(View)
        /// 팝오버 열림 상태 — `CHALLAProfileBar`가 바 탭·바깥 탭을 Binding으로 직접 쓴다.
        case binding(BindingAction<State>)
        case detailResponse(Result<RoomDetail, RoomError>)
        case delegate(Delegate)

        public enum View: Sendable {
            case task
            case backButtonTapped
            case copyInviteCodeTapped
            case shootButtonTapped
            case chatButtonTapped
        }

        /// 부모(App)에게만 알린다. 화면 전환은 App이 조립한다.
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case closeTapped
            case shootTapped
            case chatTapped
        }
    }

    // MARK: - Init

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.fetchRoomDetailUseCase) var fetchRoomDetailUseCase
    @Dependency(\.copyToPasteboard) var copyToPasteboard

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .view(.task):
                state.detailLoad = .loading
                return fetchDetail(id: state.room.id)

            case let .detailResponse(.success(detail)):
                state.detailLoad = .loaded
                state.detail = detail
                // 서버가 준 최신 방 정보로 갱신 — 홈에서 받은 값이 그 사이 낡았을 수 있다.
                state.room = detail.room
                return .none

            case .detailResponse(.failure):
                state.detailLoad = .failed
                return .none

            case .view(.backButtonTapped):
                return .send(.delegate(.closeTapped))

            // BindingReducer가 열림 값을 먼저 쓴다. 여는 순간 조회가 실패해 있으면
            // 다시 시도한다 — 얼럿 없이 여기가 복구 지점이다.
            case .binding(\.isInvitePopoverPresented):
                if state.isInvitePopoverPresented, state.detailLoad == .failed {
                    state.detailLoad = .loading
                    return fetchDetail(id: state.room.id)
                }
                return .none

            case .binding:
                return .none

            case .view(.copyInviteCodeTapped):
                guard let code = state.detail?.invitationCode else { return .none }
                return .run { [copyToPasteboard] _ in
                    await copyToPasteboard.run(code)
                }

            case .view(.shootButtonTapped):
                return .send(.delegate(.shootTapped))

            case .view(.chatButtonTapped):
                return .send(.delegate(.chatTapped))

            case .delegate:
                return .none
            }
        }
    }

    private enum CancelID { case detail }

    private func fetchDetail(id: Room.ID) -> Effect<Action> {
        .run { [fetchRoomDetailUseCase] send in
            do {
                let detail = try await fetchRoomDetailUseCase.run(id)
                await send(.detailResponse(.success(detail)))
            } catch let error as RoomError {
                await send(.detailResponse(.failure(error)))
            } catch is CancellationError {
            } catch {
                await send(.detailResponse(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.detail, cancelInFlight: true)
    }
}
