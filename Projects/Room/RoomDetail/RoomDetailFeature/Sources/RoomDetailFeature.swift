import ComposableArchitecture
import Foundation
import PhotoDomain
import RoomDomain
import ShootEntry

/// 방 상세 화면. 홈에서 받은 `Room`으로 제목·그리드를 즉시 그리고,
/// 초대 코드·참여자는 진입 후 조회해 채운다. 처음 들어온 기기면 초대 코드 팝오버를
/// 열고 툴팁을 붙였다가 닫힐 때 본 것으로 기록하고, 인화 대기 방이면 토스트로 알린다.
/// 화면 전환은 전부 `delegate`로 App에 알린다.
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
        /// 팝오버 아래 초대 안내 툴팁. 첫 진입에만 켜지고, 팝오버가 닫힐 때 함께 내려간다.
        public var isInviteGuidePresented = false
        /// 상세 성공 응답은 화면 진입 후에도 다시 올 수 있다.
        /// 예: 카운트다운 0초 후 상태 갱신, 상세 조회 실패 후 재시도.
        /// 초대 안내는 화면 진입당 한 번만 확인하기 위해 사용한다.
        public var hasCheckedInviteGuide = false
        /// 안내 토스트. nil이면 숨김 — 타이머가 일정 시간 뒤 거둔다.
        /// 뜨는 자리를 함께 들고 다닌다: 인화 대기 안내는 상단, 전체 다운로드 결과는 버튼 가까운 하단.
        public var toast: Toast?
        /// 시스템 공유 시트 열림. 딤·닫기는 시스템이 관리하고 우리는 이 값만 소유한다.
        public var isSharePresented = false
        /// 인화 대기 토스트를 이미 띄웠는지 — 알람 재조회가 같은 응답을 줘도 다시 띄우지 않는다.
        public var hasShownPrintWaitingToast = false
        /// 인화된 사진들 (찍힌 순). 그리드가 배열 순서를 슬롯 번호와 짝짓는다.
        public var photos: [Photo] = []
        /// 촬영 화면에 들어갈 준비(목록 조회·권한 요청) 중. 사진 찍기 버튼이 로딩으로 바뀌고 다시 눌리지 않는다.
        public var isPreparingShoot = false
        /// 인화 완료 안내(필름)를 띄우고 있는지. 방마다 처음 한 번만 참이 된다.
        public var isPrintNoticePresented = false
        /// 안내를 띄울지 이미 물어봤는지. 상세·사진 두 응답에서 확인하므로 두 번 조회하지 않게 막는다.
        public var didCheckPrintNotice = false
        public var downloadAll: DownloadAllState = .idle
        /// 조회 실패 얼럿. 다시 시도해도 실패하면 다시 뜬다.
        @Presents public var alert: AlertState<Action.Alert>?
        /// nil이면 확인 드로어를 닫는다.
        public var drawer: Drawer?
        /// 이 화면에서 인화 완료 확인 기록을 이미 보냈는지 — 재시도·알람 재조회마다 다시 보내지 않게 막는다.
        public var hasReportedPrintCompletionCheck = false

        /// 공유 시트에 실을 초대 링크. 상세가 오기 전엔 nil — 공유 버튼도 그때만 동작한다.
        public var inviteShareURL: URL? {
            detail.flatMap { InviteLink.url(code: $0.invitationCode) }
        }

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
        /// 첫 진입 확인이 끝났고 안내를 띄워야 한다 — 이미 봤으면 이 액션은 오지 않는다.
        case inviteGuideNeeded
        /// 이 방의 인화 완료 안내를 아직 안 봤다 — 띄울 차례다.
        /// 봤으면 아무 일도 일어나지 않아 액션도 오지 않는다.
        case printNoticeReady

        /// 방에 누가 새로 들어왔다(또는 소켓이 다시 붙었다) — 참여자를 다시 조회할 차례.
        /// 이 화면은 소켓을 직접 구독하지 않는다. 앱 루트가 받아서 보내 준다.
        case memberJoined
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
            case shareInviteCodeTapped
            case shootButtonTapped
            case chatButtonTapped
            case downloadAllTapped
            /// 사진 조회에 실패했을 때 다시 받는다 — 사진만 실패하면 얼럿이 없어 이 자리가 유일한 재시도 수단이다.
            case retryPhotosTapped
            case leaveWhileDownloadingConfirmed
            case drawerDismissed
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
    @Dependency(\.shouldShowInviteGuideUseCase) var shouldShowInviteGuideUseCase
    @Dependency(\.markInviteGuideSeenUseCase) var markInviteGuideSeenUseCase
    @Dependency(\.fetchRoomDetailUseCase) var fetchRoomDetailUseCase
    @Dependency(\.fetchRoomPhotosUseCase) var fetchRoomPhotosUseCase
    @Dependency(\.saveAllPhotosUseCase) var saveAllPhotosUseCase
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
            // 첫 진입 안내 확인은 여기가 아니라 첫 상세 성공에서 한다 (checkInviteGuide 주석).
            case .view(.task), .alert(.presented(.retryTapped)):
                return fetchAll(&state)

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
                    showPrintWaitingToast(&state, room: detail.room),
                    checkInviteGuide(&state),
                    printNotice
                )

            case .memberJoined:
                // 조용히 다시 부른다 — detailLoad를 건드리지 않아 아바타 바가 깜빡이지 않는다.
                return refreshDetailQuietly(id: state.room.id)

            case .printCompletionReached:
                // 화면 카운트다운은 이미 0:00:00 — 서버가 인화 완료로 넘어갔는지 다시 묻는다.
                state.photosLoad = .loading
                return .merge(
                    fetchDetail(id: state.room.id),
                    fetchPhotos(id: state.room.id)
                )

            case .inviteGuideNeeded:
                state.isInvitePopoverPresented = true
                state.isInviteGuidePresented = true
                return .none

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
                state.photosLoad = .loaded
                state.photos = photos
                // 필름에 실을 사진이 생겼다 — 대개 여기서 안내 여부가 정해진다.
                return checkPrintNotice(state: &state)

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

            // 팝오버가 어떤 경로로든(바 재탭·바깥 탭) 닫히면 안내도 끝난 것 — 내리고 기록한다.
            case .binding(\.isInvitePopoverPresented):
                guard !state.isInvitePopoverPresented, state.isInviteGuidePresented else { return .none }
                state.isInviteGuidePresented = false
                // 팝오버를 닫고 곧장 뒤로 나가도 기록은 안 날아간다 — 서버 요청처럼 응답을
                // 기다리는 게 아니라 UserDefaults에 쓰는 순간 끝나서, 화면이 사라지며
                // 이펙트가 취소되는 시점엔 이미 저장된 뒤다.
                return .run { [markInviteGuideSeenUseCase] _ in
                    await markInviteGuideSeenUseCase.run()
                }

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

            case .view(.shareInviteCodeTapped):
                guard state.inviteShareURL != nil else { return .none }
                state.isSharePresented = true
                return .none

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

    enum CancelID {
        case detail, photos, toast, printRefresh, prepareShoot, inviteGuide, printNotice, downloadAll
    }

    private enum Const {
        // TODO: 노출 시간은 기획 미확정 — ProfileSetup과 같은 임시값. 확정 시 교체할 것.
        static let toastDuration: Duration = .seconds(2)
        static let printWaitingToastMessage = "인화 대기 중이에요! 조금만 기다려주세요"

        static func saveAllToast(saved: Int, total: Int) -> String {
            saved == total ? "사진 \(total)장을 저장했어요" : "\(total)장 중 \(saved)장을 저장했어요"
        }
    }
}

// MARK: - Effects

/// 리듀서 본문과 이펙트 헬퍼를 나눈다 — 초대 안내(#99)와 인화 완료 안내(#102)가 합쳐지며
/// 타입 본문이 린트 상한(250줄)을 넘었다. 같은 파일이라 private 멤버 접근은 그대로다.
private extension RoomDetailFeature {

    /// 상세와 사진을 함께 부른다. 사진은 방 상태를 따지지 않는다 — 촬영 중이면 빈 배열이
    /// 오고 그리드도 빈 슬롯을 그리며, 상태로 걸러내면 홈에서 받은 상태가 낡은 경우
    /// (그 사이 인화 단계로 넘어간 방)를 따라잡아야 한다.
    func fetchAll(_ state: inout State) -> Effect<Action> {
        state.detailLoad = .loading
        state.photosLoad = .loading
        return .merge(
            fetchDetail(id: state.room.id),
            fetchPhotos(id: state.room.id)
        )
    }

    /// 첫 상세 성공에 한 번, 이 기기에서 처음 들어왔는지 확인하고 처음일 때만 안내 액션을 보낸다.
    /// 진입(.task)이 아니라 상세 성공 뒤에 확인한다 — 참여자 바가 그려진 다음이라 팝오버가
    /// 여는 모션과 함께 나타나고, 조회가 실패한 화면 뒤에 보이지 않는 열림 상태가 남지 않는다.
    func checkInviteGuide(_ state: inout State) -> Effect<Action> {
        guard !state.hasCheckedInviteGuide else { return .none }
        state.hasCheckedInviteGuide = true
        return .run { [shouldShowInviteGuideUseCase] send in
            guard await shouldShowInviteGuideUseCase.run() else { return }
            await send(.inviteGuideNeeded)
        }
        .cancellable(id: CancelID.inviteGuide, cancelInFlight: true)
    }

    /// 인화 대기 방에 들어왔다고 토스트로 알린다. 화면당 한 번만 —
    /// 카운트다운 알람의 재조회가 같은 대기 응답을 줘도 다시 띄우지 않는다.
    func showPrintWaitingToast(_ state: inout State, room: Room) -> Effect<Action> {
        guard room.status == .printWaiting, !state.hasShownPrintWaitingToast else { return .none }
        state.hasShownPrintWaitingToast = true
        state.toast = Toast(Const.printWaitingToastMessage, placement: .top)
        return toastTimer()
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

    /// 실패해도 얼럿을 띄우지 않는다 — 배경에서 도는 조회라 사용자가 부른 적이 없다.
    private func refreshDetailQuietly(id: Room.ID) -> Effect<Action> {
        .run { [fetchRoomDetailUseCase] send in
            guard let detail = try? await fetchRoomDetailUseCase.run(id) else { return }
            await send(.detailResponse(.success(detail)))
        }
        .cancellable(id: CancelID.detail, cancelInFlight: true)
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

    /// 인화 완료 방에 처음 들어왔는지 기기 기록에 묻는다.
    ///
    /// 사진까지 도착해야 묻는다 — 필름에 실을 것이 없는 채로 띄우면 빈 필름이 나온다.
    /// 사진 조회가 끝내 실패하면 안내는 뜨지 않고 봤다는 기록도 남지 않아 다음 진입에 다시 뜬다.
    ///
    /// 상세·사진 두 응답에서 불리므로 한 번 물어본 뒤에는 다시 묻지 않는다 —
    /// 두 번 물으면 안내를 닫은 직후 도착한 응답이 안내를 다시 띄운다.
    func checkPrintNotice(state: inout State) -> Effect<Action> {
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

    /// 일정 시간 뒤 토스트를 거둔다. 복사를 연타하면 이전 타이머를 취소해 노출 시간이 처음부터 다시 센다.
    func toastTimer() -> Effect<Action> {
        .run { [clock] send in
            try await clock.sleep(for: Const.toastDuration)
            await send(.toastDismissed)
        }
        .cancellable(id: CancelID.toast, cancelInFlight: true)
    }
}
