import ComposableArchitecture
import Foundation
import PhotoDomain
import RoomDomain
import ShootEntry

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
        /// 촬영 화면에 들어갈 준비(목록 조회·권한 요청) 중. 사진 찍기 버튼이 로딩으로 바뀌고 다시 눌리지 않는다.
        public var isPreparingShoot = false
        /// 인화 완료 안내(필름)를 띄우고 있는지. 방마다 처음 한 번만 참이 된다.
        public var isPrintNoticePresented = false
        /// 안내를 띄울지 이미 물어봤는지. 상세·사진 두 응답에서 확인하므로 두 번 조회하지 않게 막는다.
        public var didCheckPrintNotice = false
        /// 조회 실패 얼럿. 다시 시도해도 실패하면 다시 뜬다.
        @Presents public var alert: AlertState<Action.Alert>?
        /// 이 화면에서 인화 완료 확인 기록을 이미 보냈는지 — 재시도·알람 재조회마다 다시 보내지 않게 막는다.
        public var hasReportedPrintCompletionCheck = false

        public init(room: Room) {
            self.room = room
        }
    }

    /// 조회가 안 끝난 것과 실패한 것을 구분한다.
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
        case shootPreparationResponse(Result<CameraEntry, ShootPreparationError>)
        /// 인화 완료 예정 시각에 도달 — 서버가 상태를 바꿨는지 확인할 차례.
        case printCompletionReached
        /// 이 방의 인화 완료 안내를 아직 안 봤다 — 띄울 차례다.
        /// 봤으면 아무 일도 일어나지 않아 액션도 오지 않는다.
        case printNoticeReady
        case toastDismissed
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        public enum Alert: Equatable, Sendable {
            case retryTapped
            /// 카메라·사진첩 얼럿이 함께 쓴다 — 둘 다 앱 설정 화면 한 곳으로 간다.
            case openSettingsTapped
        }

        public enum View: Sendable {
            case task
            case backButtonTapped
            case settingsButtonTapped
            case copyInviteCodeTapped
            case shootButtonTapped
            case chatButtonTapped
            /// 사진이 있는 슬롯을 탭 — 그 사진을 펼친 채 사진 상세로 들어간다.
            case photoTapped(Photo.ID)
            /// 필름이 다 내려가 안내가 끝났다 — 이 시점에 봤다고 기록해 다음 진입부터는 뜨지 않는다.
            case printNoticeDismissed
        }

        /// 부모(App)에게만 알린다. 화면 전환은 App이 조립한다.
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case closeTapped
            case settingsTapped
            /// 촬영 준비가 끝났다 — 목록·권한이 모두 갖춰졌으니 카메라 화면을 띄우면 된다.
            case cameraRequested(CameraEntry)
            case chatTapped
            /// 사진 상세를 연다. App이 `PhotoDetailFeature`를 조립한다 (규칙 3).
            case photoTapped(Photo.ID)
        }
    }

    // MARK: - Init

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.checkPrintCompletionUseCase) var checkPrintCompletionUseCase
    @Dependency(\.fetchRoomDetailUseCase) var fetchRoomDetailUseCase
    @Dependency(\.fetchRoomPhotosUseCase) var fetchRoomPhotosUseCase
    @Dependency(\.copyToPasteboard) var copyToPasteboard
    @Dependency(\.shouldShowPrintNoticeUseCase) var shouldShowPrintNoticeUseCase
    @Dependency(\.markPrintNoticeSeenUseCase) var markPrintNoticeSeenUseCase
    @Dependency(\.openCameraSettingsUseCase) var openCameraSettingsUseCase
    @Dependency(\.continuousClock) var clock
    /// 현재 시각. 인화 완료까지 남은 시간을 계산할 때 쓴다 — 테스트가 고정할 수 있게 주입받는다.
    @Dependency(\.date) var date

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            // 진입과 재시도가 같은 일을 한다 — 상세와 사진을 다시 부른다.
            case .view(.task), .alert(.presented(.retryTapped)):
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
                // 홈에서 받은 방은 목록 조회 시점의 값이라, 방금 조회한 상세 응답의 값으로 덮는다.
                state.room = detail.room
                // 사진이 먼저 도착해 있었다면 여기서 안내를 확인한다 (인화 대기로 들어왔다가 완료로 넘어간 경우 포함).
                let printNotice = checkPrintNotice(state: &state)
                return .merge(
                    refreshAtPrintCompletion(room: detail.room),
                    reportPrintCompletionCheck(&state, room: detail.room),
                    printNotice
                )

            case .printCompletionReached:
                // 화면 카운트다운은 이미 0:00:00 — 서버가 인화 완료로 넘어갔는지 다시 묻는다.
                return .merge(
                    fetchDetail(id: state.room.id),
                    fetchPhotos(id: state.room.id)
                )

            case .printNoticeReady:
                state.isPrintNoticePresented = true
                return .none

            // 닫는 시점에 기록한다 — 띄우자마자 기록하면 앱이 강제 종료된 사용자는 안내를 못 본 채 놓친다.
            case .view(.printNoticeDismissed):
                state.isPrintNoticePresented = false
                return .run { [markPrintNoticeSeenUseCase, roomID = state.room.id] _ in
                    await markPrintNoticeSeenUseCase.run(roomID)
                }

            case let .photosResponse(.success(photos)):
                // 서버가 찍힌 순서대로 주므로 배열 순서를 그대로 슬롯 번호(1번 = 첫 장)로 쓴다.
                state.photos = photos
                // 필름에 실을 사진이 생겼다 — 대개 여기서 안내 여부가 정해진다.
                return checkPrintNotice(state: &state)

            case .photosResponse(.failure):
                // 사진만 실패하면 얼럿을 띄우지 않는다 — 상세가 성공했으면 화면 대부분이 그려져 있고,
                // 상세까지 실패했다면 그쪽 얼럿의 "다시 시도"가 사진도 함께 부른다.
                return .none

            case let .detailResponse(.failure(error)):
                state.detailLoad = .failed
                // TODO: 얼럿 제목·버튼 문구는 임의 작성본 — 기획 정책 확정 시 교체할 것 (홈과 같은 상태).
                state.alert = AlertState {
                    TextState("방 정보를 불러오지 못했어요")
                } actions: {
                    ButtonState(action: .retryTapped) { TextState("다시 시도") }
                    ButtonState(role: .cancel) { TextState("확인") }
                } message: {
                    TextState(error.userMessage)
                }
                return .none

            case .view(.backButtonTapped):
                return .send(.delegate(.closeTapped))

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

            case .view(.settingsButtonTapped):
                return .send(.delegate(.settingsTapped))

            // MARK: 촬영 진입

            // 준비가 끝나야 카메라로 넘어간다 — 홈의 촬영 뱃지와 같은 준비를 같은 코드로 한다.
            case .view(.shootButtonTapped):
                guard !state.isPreparingShoot else { return .none }
                state.isPreparingShoot = true
                return prepareShoot(roomID: state.room.id)

            case let .shootPreparationResponse(.success(entry)):
                state.isPreparingShoot = false
                return .send(.delegate(.cameraRequested(entry)))

            case let .shootPreparationResponse(.failure(error)):
                state.isPreparingShoot = false
                state.alert = error.alert(openSettings: .openSettingsTapped)
                return .none

            case .alert(.presented(.openSettingsTapped)):
                return .run { [openCameraSettingsUseCase] _ in
                    await openCameraSettingsUseCase.run()
                }

            case .view(.chatButtonTapped):
                return .send(.delegate(.chatTapped))

            case let .view(.photoTapped(id)):
                return .send(.delegate(.photoTapped(id)))

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private enum CancelID { case detail, photos, toast, printRefresh, prepareShoot, printNotice }

    private enum Const {
        // TODO: 노출 시간은 기획 미확정 — ProfileSetup과 같은 임시값. 확정 시 교체할 것.
        static let toastDuration: Duration = .seconds(2)
        static let copyToastMessage = "초대 코드를 복사했어요"
    }

    /// 촬영에 필요한 것(목록·LUT·권한)은 `ShootEntry`가 받아 온다 — 홈의 촬영 뱃지와 같은 준비다.
    /// 의존성 해석은 이펙트 바깥에서 끝낸다 (`ShootPreparation()`).
    private func prepareShoot(roomID: Room.ID) -> Effect<Action> {
        let preparation = ShootPreparation()

        return .run { send in
            let result = try await preparation.run(roomID: roomID)
            await send(.shootPreparationResponse(result))
        }
        .cancellable(id: CancelID.prepareShoot, cancelInFlight: true)
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
                // 그리드는 리액션을 그리지 않으므로 목록만 받는다 (리액션은 사진 상세에서 지연 조회).
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

    /// 인화 완료 방에 처음 들어왔는지 기기 기록에 묻는다.
    ///
    /// 사진까지 도착해야 묻는다 — 필름에 실을 것이 없는 채로 띄우면 빈 필름이 나온다.
    /// 사진 조회가 끝내 실패하면 안내는 뜨지 않고 봤다는 기록도 남지 않아 다음 진입에 다시 뜬다.
    ///
    /// 상세·사진 두 응답에서 불리므로 한 번 물어본 뒤에는 다시 묻지 않는다 —
    /// 두 번 물으면 안내를 닫은 직후 도착한 응답이 안내를 다시 띄운다.
    private func checkPrintNotice(state: inout State) -> Effect<Action> {
        guard state.room.status == .printed, !state.photos.isEmpty, !state.didCheckPrintNotice
        else { return .none }
        state.didCheckPrintNotice = true

        return .run { [shouldShowPrintNoticeUseCase, roomID = state.room.id] send in
            guard await shouldShowPrintNoticeUseCase.run(roomID) else { return }
            await send(.printNoticeReady)
        }
        .cancellable(id: CancelID.printNotice, cancelInFlight: true)
    }

    /// 인화 완료 예정 시각에 한 번 깨어나 상세·사진을 재조회하는 알람.
    ///
    /// 인화 대기 + 예정 시각이 미래일 때만 건다. 시각이 지났는데 상태가 그대로면(서버 전환 지연)
    /// 다시 걸지 않는다 — 걸면 0초짜리 알람이 반복돼 무한 재조회가 된다.
    private func refreshAtPrintCompletion(room: Room) -> Effect<Action> {
        guard room.status == .printWaiting,
              let completedAt = room.photoPrintCompletedAt,
              completedAt > date.now
        else { return .none }

        return .run { [clock, date] send in
            try await clock.sleep(for: .seconds(completedAt.timeIntervalSince(date.now)))
            await send(.printCompletionReached)
        }
        .cancellable(id: CancelID.printRefresh, cancelInFlight: true)
    }

    /// 인화 완료 방에 들어왔다고 서버에 기록한다 (`PUT .../photo-print-completion/check`) —
    /// 이 기록이 홈 확인하기 카드를 다음 목록 조회부터 하단 "인화 완료" 목록으로 내려보낸다.
    ///
    /// 홈(확인하기 탭)이 아니라 여기서 부르는 이유: 탭 직후 화면이 상세로 바뀌면서
    /// 홈 State가 사라지고, 홈이 보내던 요청도 함께 취소돼 기록이 유실됐다.
    /// 상세는 사용자가 보는 동안 화면에 남아 있어 요청이 끝까지 나간다.
    /// 실패는 무시한다 — 확인하기 카드가 남아 다음 진입 때 다시 시도된다.
    private func reportPrintCompletionCheck(_ state: inout State, room: Room) -> Effect<Action> {
        guard room.status == .printed, !state.hasReportedPrintCompletionCheck else { return .none }
        state.hasReportedPrintCompletionCheck = true
        return .run { [checkPrintCompletionUseCase] _ in
            try? await checkPrintCompletionUseCase.run(room.id)
        }
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
