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
        /// 사진 목록 조회 상태. 아직 받는 중인 것과 실패한 것을 구분해야
        /// 인화 완료 방 하단에 "불러오지 못했어요"가 잘못 뜨지 않는다.
        public var photosLoad: LoadState = .notRequested
        /// 아바타 탭으로 여는 초대 코드 팝오버.
        public var isInvitePopoverPresented = false
        /// nil이면 토스트를 숨긴다.
        public var toast: Toast?
        /// 인화된 사진들 (찍힌 순). 그리드가 배열 순서를 슬롯 번호와 짝짓는다.
        public var photos: [Photo] = []
        /// 촬영 화면에 들어갈 준비(목록 조회·권한 요청) 중. 사진 찍기 버튼이 로딩으로 바뀌고 다시 눌리지 않는다.
        public var isPreparingShoot = false
        public var downloadAll: DownloadAllState = .idle
        /// 조회 실패 얼럿. 다시 시도해도 실패하면 다시 뜬다.
        @Presents public var alert: AlertState<Action.Alert>?
        /// nil이면 확인 드로어를 닫는다.
        public var drawer: Drawer?
        /// 이 화면에서 인화 완료 확인 기록을 이미 보냈는지 — 재시도·알람 재조회마다 다시 보내지 않게 막는다.
        public var hasReportedPrintCompletionCheck = false
        /// 인화 대기 안내 토스트를 이 화면에서 이미 띄웠는지. 재조회 때마다 다시 뜨지 않게 막는다.
        public var didShowPrintWaitingToast = false

        public init(room: Room) {
            self.room = room
        }
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
        case toastDismissed
        case saveAllEvent(SaveAllPhotosEvent)
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
            case downloadAllTapped
            /// 사진 조회에 실패했을 때 다시 받는다 — 사진만 실패하면 얼럿이 없어 이 자리가 유일한 재시도 수단이다.
            case retryPhotosTapped
            case leaveWhileDownloadingConfirmed
            case drawerDismissed
            /// 사진이 있는 슬롯을 탭 — 그 사진을 펼친 채 사진 상세로 들어간다.
            case photoTapped(Photo.ID)
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
    @Dependency(\.saveAllPhotosUseCase) var saveAllPhotosUseCase
    @Dependency(\.copyToPasteboard) var copyToPasteboard
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
                state.photosLoad = .loading
                // 사진은 방 상태를 따지지 않고 부른다 — 촬영 중이면 빈 배열이 오고 그리드도 빈 슬롯을 그린다.
                // 상태로 걸러내면 홈에서 받은 상태가 낡은 경우(그 사이 인화 단계로 넘어간 방)를 따라잡아야 한다.
                let roomID = state.room.id
                let waitingToast = printWaitingToast(&state)
                return .merge(
                    waitingToast,
                    fetchDetail(id: roomID),
                    fetchPhotos(id: roomID)
                )

            case let .detailResponse(.success(detail)):
                state.detailLoad = .loaded
                state.detail = detail
                // 홈에서 받은 방은 목록 조회 시점의 값이라, 방금 조회한 상세 응답의 값으로 덮는다.
                state.room = detail.room
                let waitingToast = printWaitingToast(&state)
                let completionCheck = reportPrintCompletionCheck(&state, room: detail.room)
                return .merge(
                    waitingToast,
                    refreshAtPrintCompletion(room: detail.room),
                    completionCheck
                )

            case .printCompletionReached:
                // 화면 카운트다운은 이미 0:00:00 — 서버가 인화 완료로 넘어갔는지 다시 묻는다.
                state.photosLoad = .loading
                return .merge(
                    fetchDetail(id: state.room.id),
                    fetchPhotos(id: state.room.id)
                )

            case let .photosResponse(.success(photos)):
                state.photosLoad = .loaded
                state.photos = photos
                return .none

            case .photosResponse(.failure):
                state.photosLoad = .failed
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
                // 중단 후 재다운로드하면 사진이 중복 저장될 수 있어 확인을 받는다.
                guard !state.downloadAll.isRunning else {
                    state.drawer = .leaveWhileDownloading
                    return .none
                }
                return .send(.delegate(.closeTapped))

            case .view(.leaveWhileDownloadingConfirmed):
                state.drawer = nil
                state.downloadAll = .idle
                return .merge(
                    .cancel(id: CancelID.downloadAll),
                    .send(.delegate(.closeTapped))
                )

            case .view(.drawerDismissed):
                state.drawer = nil
                return .none

            case .binding:
                return .none

            case .view(.copyInviteCodeTapped):
                guard let code = state.detail?.invitationCode else { return .none }
                state.toast = Toast(Const.copyToastMessage, placement: .top)
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

            case .view(.retryPhotosTapped):
                state.photosLoad = .loading
                return fetchPhotos(id: state.room.id)

            case .view(.downloadAllTapped):
                return startDownloadAll(&state)

            case let .saveAllEvent(.progress(completed, _, total)):
                state.downloadAll = .running(completed: completed, total: total)
                return .none

            case let .saveAllEvent(.finished(saved, _, total)):
                state.downloadAll = .idle
                state.toast = Toast(Const.saveAllToast(saved: saved, total: total), placement: .bottom)
                return toastTimer()

            case let .saveAllEvent(.aborted(error)):
                state.downloadAll = .idle
                state.alert = Self.photoLibraryAlert(error: error)
                return .none

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

    enum CancelID { case detail, photos, toast, printRefresh, prepareShoot, downloadAll }
}

// MARK: - 내부 상수 · 이펙트

/// 리듀서 본문 길이 제한(250줄)에 걸려 빼냈다. 같은 파일이라 접근 범위(private)는 그대로다.
private extension RoomDetailFeature {
    enum Const {
        // TODO: 노출 시간은 기획 미확정 — ProfileSetup과 같은 임시값. 확정 시 교체할 것.
        static let toastDuration: Duration = .seconds(2)
        static let copyToastMessage = "초대 코드를 복사했어요"
        static let printWaitingToastMessage = "인화 대기 중이에요! 조금만 기다려주세요"

        static func saveAllToast(saved: Int, total: Int) -> String {
            saved == total ? "사진 \(total)장을 저장했어요" : "\(total)장 중 \(saved)장을 저장했어요"
        }
    }

    /// 촬영에 필요한 것(목록·LUT·권한)은 `ShootEntry`가 받아 온다 — 홈의 촬영 뱃지와 같은 준비다.
    /// 의존성 해석은 이펙트 바깥에서 끝낸다 (`ShootPreparation()`).
    func prepareShoot(roomID: Room.ID) -> Effect<Action> {
        let preparation = ShootPreparation()

        return .run { send in
            let result = try await preparation.run(roomID: roomID)
            await send(.shootPreparationResponse(result))
        }
        .cancellable(id: CancelID.prepareShoot, cancelInFlight: true)
    }

    func fetchDetail(id: Room.ID) -> Effect<Action> {
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

    /// 인화 완료 예정 시각에 한 번 깨어나 상세·사진을 재조회하는 알람.
    ///
    /// 인화 대기 + 예정 시각이 미래일 때만 건다. 시각이 지났는데 상태가 그대로면(서버 전환 지연)
    /// 다시 걸지 않는다 — 걸면 0초짜리 알람이 반복돼 무한 재조회가 된다.
    func refreshAtPrintCompletion(room: Room) -> Effect<Action> {
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
    func reportPrintCompletionCheck(_ state: inout State, room: Room) -> Effect<Action> {
        guard room.status == .printed, !state.hasReportedPrintCompletionCheck else { return .none }
        state.hasReportedPrintCompletionCheck = true
        return .run { [checkPrintCompletionUseCase] _ in
            try? await checkPrintCompletionUseCase.run(room.id)
        }
    }

    /// 인화 대기 방에 들어왔을 때 한 번 띄우는 안내. 남은 시간은 하단 카운트다운이 계속 보여준다.
    ///
    /// 진입과 상세 응답 두 곳에서 부른다 — 홈에서 받은 상태가 낡아 진입 시점엔 촬영 중으로 보여도
    /// 상세 응답에서 따라잡는다. 플래그로 화면당 한 번만 뜨게 막는다(인화 완료 알람의 재조회 포함).
    func printWaitingToast(_ state: inout State) -> Effect<Action> {
        guard state.room.status == .printWaiting, !state.didShowPrintWaitingToast else {
            return .none
        }
        state.didShowPrintWaitingToast = true
        state.toast = Toast(Const.printWaitingToastMessage, placement: .top)
        return toastTimer()
    }

    /// 일정 시간 뒤 토스트를 거둔다. 복사를 연타하면 이전 타이머를 취소해 노출 시간이 처음부터 다시 센다.
    func toastTimer() -> Effect<Action> {
        .run { [clock] send in
            try await clock.sleep(for: Const.toastDuration)
            await send(.toastDismissed)
        }
        .cancellable(id: CancelID.toast, cancelInFlight: true)
    }
}
