import ComposableArchitecture
import SettingDomain

/// 알림 설정 화면의 TCA Feature.
///
/// 서비스 알림 수신 여부(로컬 저장값)를 토글하고, 시스템 알림 권한이 꺼져 있으면
/// 설정 앱으로 보내는 배너를 띄운다.
///
/// **delegate가 없다.** 알림 설정은 설정 메인 화면에 표시되지 않아 부모가 알 필요가 없다.
@Reducer
public struct NotificationSettingFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {

        /// 서비스 알림 수신 여부 (로컬 저장값).
        public var isServiceNotificationEnabled = NotificationSetting.default.isServiceEnabled

        /// 시스템 알림 권한. `nil`이면 아직 조회 전이다 —
        /// 조회 전에 배너를 띄웠다가 권한이 허용이면 곧바로 사라져 깜빡인다.
        public var systemAuthorization: NotificationAuthorizationStatus?

        /// 권한이 허용이 아닐 때만 배너를 보여준다 (시안에 허용 상태 배너가 없다).
        ///
        /// `.denied`뿐 아니라 `.notDetermined`도 포함한다 — 사용자 눈에는 둘 다 "알림이 꺼져 있음"이다.
        /// 탭했을 때의 동작은 두 상태가 다르다 (`permissionBannerTapped` 처리 참고).
        public var showsPermissionBanner: Bool {
            guard let systemAuthorization else { return false }
            return systemAuthorization != .authorized
        }

        public init() {}
    }

    // MARK: - Action

    public enum Action: ViewAction, Sendable {

        /// UI에서만 트리거되는 액션 (`@ViewAction` 뷰가 `send(...)`로 호출).
        public enum ViewAction: Sendable {
            case onAppear
            /// 앱이 포그라운드로 돌아왔다 (`scenePhase == .active`).
            /// 설정 앱에서 권한을 바꾸고 돌아오는 경로라 다시 조회해야 한다.
            case sceneBecameActive
            case permissionBannerTapped
            case serviceNotificationToggled(Bool)
            case backButtonTapped
        }

        case view(ViewAction)

        /// 내부 — 저장값 + 권한 상태를 한 번에 받는다.
        case notificationSettingsLoaded(NotificationSettingsSnapshot)

        /// 내부 — 권한 요청이 끝난 뒤의 상태. 허용되면 배너가 사라진다.
        case authorizationRequested(NotificationAuthorizationStatus)
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.loadNotificationSettingsUseCase) var loadNotificationSettingsUseCase
    @Dependency(\.updateServiceNotificationUseCase) var updateServiceNotificationUseCase
    @Dependency(\.requestNotificationAuthorizationUseCase) var requestNotificationAuthorizationUseCase
    @Dependency(\.openSystemNotificationSettingsUseCase) var openSystemNotificationSettingsUseCase
    @Dependency(\.dismiss) var dismiss

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.onAppear), .view(.sceneBecameActive):
                // 두 액션이 같은 취소 ID를 공유한다 —
                // 설정 앱에 다녀오는 동안 남아 있던 조회는 새 조회가 덮어쓴다.
                return .run { [loadNotificationSettingsUseCase] send in
                    await send(.notificationSettingsLoaded(loadNotificationSettingsUseCase.run()))
                }
                .cancellable(id: CancelID.load, cancelInFlight: true)

            case let .notificationSettingsLoaded(snapshot):
                state.isServiceNotificationEnabled = snapshot.setting.isServiceEnabled
                state.systemAuthorization = snapshot.authorization
                return .none

            case .view(.permissionBannerTapped):
                switch state.systemAuthorization {
                case .notDetermined:
                    // 아직 묻지 않은 상태에서는 앱이 직접 물을 수 있다.
                    // 설정 앱으로 보내면 안 된다 — 원격 알림에 등록된 적 없는 앱은
                    // 설정 앱에 알림 항목이 보이지 않아 사용자가 켤 방법이 없다.
                    return .run { [requestNotificationAuthorizationUseCase] send in
                        await send(.authorizationRequested(requestNotificationAuthorizationUseCase.run()))
                    }
                    .cancellable(id: CancelID.requestAuthorization, cancelInFlight: true)

                case .denied:
                    // 한 번 거절하면 앱이 다시 물을 수 없다 — 설정 앱에서 켜야 한다.
                    // 앱을 벗어나는 일이라 되돌아올 값이 없어 취소 ID를 붙이지 않는다.
                    return .run { [openSystemNotificationSettingsUseCase] _ in
                        await openSystemNotificationSettingsUseCase.run()
                    }

                case .authorized, nil:
                    // 배너가 없는 상태라 탭이 올 수 없다.
                    return .none
                }

            case let .authorizationRequested(status):
                state.systemAuthorization = status
                return .none

            case let .view(.serviceNotificationToggled(isOn)):
                // 낙관적 갱신 — 로컬 write라 실패 경로가 없다.
                state.isServiceNotificationEnabled = isOn
                // debounce 하지 않는다. 저장 비용이 없고 `cancelInFlight`로 마지막 값만 남는다.
                return .merge(
                    // 떠 있는 조회를 취소한다 — 늦게 도착하면 방금 뒤집은 값을 되돌린다.
                    .cancel(id: CancelID.load),
                    .run { [updateServiceNotificationUseCase] _ in
                        await updateServiceNotificationUseCase.run(isOn)
                    }
                    .cancellable(id: CancelID.save, cancelInFlight: true)
                )

            case .view(.backButtonTapped):
                return .run { [dismiss] _ in await dismiss() }
            }
        }
    }

    // MARK: - Effects

    private enum CancelID { case load, save, requestAuthorization }
}
