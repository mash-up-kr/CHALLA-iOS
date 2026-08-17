import ComposableArchitecture
import Foundation
import PhotoDomain
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
        /// 복사 완료 안내 토스트 문구. nil이면 숨김 — 타이머가 일정 시간 뒤 거둔다.
        public var toast: String?
        /// 인화된 사진들 (찍힌 순). 그리드가 배열 순서를 슬롯 번호와 짝짓는다.
        public var photos: [Photo] = []

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
        case photosResponse(Result<[Photo], PhotoError>)
        case toastDismissed
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
            // TODO: [#57] 슬롯 탭으로 사진 상세를 여는 photoTapped(Photo.ID)를 추가한다.
            // 뷰의 slot(number:)에 탭을 달고, App이 PhotoDetailFeature를 연다.
        }
    }

    // MARK: - Init

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.fetchRoomDetailUseCase) var fetchRoomDetailUseCase
    @Dependency(\.fetchRoomPhotosUseCase) var fetchRoomPhotosUseCase
    @Dependency(\.copyToPasteboard) var copyToPasteboard
    @Dependency(\.continuousClock) var clock

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .view(.task):
                state.detailLoad = .loading
                // 사진은 방 상태를 따지지 않고 부른다 — 촬영 중이면 빈 배열이 오고 그리드도 빈 슬롯을 그린다.
                // 상태로 걸러내면 홈에서 받은 상태가 낡은 경우(그 사이 인화 단계로 넘어간 방)를 따라잡아야 한다.
                return .merge(
                    fetchDetail(id: state.room.id),
                    fetchPhotos(id: state.room.id)
                )

            case let .detailResponse(.success(detail)):
                state.detailLoad = .loaded
                state.detail = detail
                // 서버가 준 최신 방 정보로 갱신 — 홈에서 받은 값이 그 사이 낡았을 수 있다.
                state.room = detail.room
                return .none

            case let .photosResponse(.success(photos)):
                // 서버가 찍힌 순서대로 주므로 배열 순서를 그대로 슬롯 번호(1번 = 첫 장)로 쓴다.
                state.photos = photos
                return .none

            case .photosResponse(.failure):
                // 상세 조회 실패와 같은 정책 — 얼럿 없이 슬롯을 빈 모습으로 둔다.
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
                state.toast = Const.copyToastMessage
                return .merge(
                    .run { [copyToPasteboard] _ in
                        await copyToPasteboard.run(code)
                    },
                    toastTimer()
                )

            case .toastDismissed:
                state.toast = nil
                return .none

            case .view(.shootButtonTapped):
                return .send(.delegate(.shootTapped))

            case .view(.chatButtonTapped):
                return .send(.delegate(.chatTapped))

            case .delegate:
                return .none
            }
        }
    }

    private enum CancelID { case detail, photos, toast }

    private enum Const {
        // TODO: 노출 시간은 기획 미확정 — ProfileSetup과 같은 임시값. 확정 시 교체할 것.
        static let toastDuration: Duration = .seconds(2)
        static let copyToastMessage = "초대 코드를 복사했어요"
    }

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

    /// 사진 목록은 PhotoDomain 소관이라 방 조회와 별개로 실패할 수 있다 — 에러도 PhotoError로 온다.
    private func fetchPhotos(id: Room.ID) -> Effect<Action> {
        .run { [fetchRoomPhotosUseCase] send in
            do {
                let photos = try await fetchRoomPhotosUseCase.run(id)
                await send(.photosResponse(.success(photos)))
            } catch let error as PhotoError {
                await send(.photosResponse(.failure(error)))
            } catch is CancellationError {
            } catch {
                await send(.photosResponse(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.photos, cancelInFlight: true)
    }

    /// 일정 시간 뒤 토스트를 거둔다. 복사를 연타하면 이전 타이머를 취소해 노출 시간이 처음부터 다시 센다.
    private func toastTimer() -> Effect<Action> {
        .run { [clock] send in
            try await clock.sleep(for: Const.toastDuration)
            await send(.toastDismissed)
        }
        .cancellable(id: CancelID.toast, cancelInFlight: true)
    }
}
