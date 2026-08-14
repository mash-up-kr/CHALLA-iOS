import ComposableArchitecture
import Foundation
import SettingData
import SettingDomain
import SettingFeature

/// 데모앱의 의존성 조립 지점 — 이 앱에서 유일하게 Data 구현체를 생성하는 곳.
///
/// 데모앱은 앱 조립 지점이므로 예외적으로 `SettingData`를 import 할 수 있다 (아키텍처 규칙 2의 유일한 예외).
/// `CHALLAApp/Sources/CompositionRoot.swift`가 같은 형태의 배선을 갖는다.
///
/// **무엇이 실제고 무엇이 스텁인가**
/// - 테마·알림 저장: 실제 `UserDefaults` (`DefaultSettingsRepository`)
/// - 프로필: 스텁 (#33 머지 후 교체)
/// - 알림 권한·설정 앱 열기: **항상 스텁**. 시뮬레이터 권한 상태에 따라 배너가 흔들리면
///   시안 대조 검증이 불가능하고, 실제로 설정 앱이 열리면 캡처 흐름이 끊긴다
/// - 외부 링크(응원·피드백): 스텁(콘솔 로그). 같은 이유로 앱 밖으로 나가지 않는다
/// - 로그아웃·탈퇴: 스텁. 실행 앱은 `AuthDomain.LogoutUseCase` 어댑터를 주입한다
enum CompositionRoot {

    /// 요청한 실행 인자에 맞는 의존성을 등록한다.
    static func register(
        arguments: DemoLaunchArguments,
        into values: inout DependencyValues
    ) {
        let settings = settingsRepository(for: arguments)

        registerProfile(state: arguments.state(of: .setting), into: &values)
        registerTheme(settings: settings, into: &values)
        registerNotification(state: arguments.state(of: .notification), settings: settings, into: &values)
        registerAccount(state: arguments.state(of: .account), into: &values)
        registerExternalLinks(into: &values)
    }

    // MARK: - 저장소

    /// `--theme` · `--serviceNotification`이 주어졌으면 그 값의 **읽기만** 고정한다
    /// (`ForcedSettingsRepository` 주석 참고).
    private static func settingsRepository(for arguments: DemoLaunchArguments) -> any SettingsRepository {
        let base = DefaultSettingsRepository()
        guard arguments.hasExplicitTheme || arguments.serviceNotification != nil else { return base }
        return ForcedSettingsRepository(
            base: base,
            theme: arguments.hasExplicitTheme ? arguments.theme : nil,
            isServiceNotificationEnabled: arguments.serviceNotification
        )
    }

    // MARK: - 프로필

    /// `--state loading`·`error`가 걸리는 유일한 의존성이다 — 설정 화면에서 실패할 수 있는 건 프로필뿐이다.
    private static func registerProfile(
        state: DemoLaunchArguments.State,
        into values: inout DependencyValues
    ) {
        switch state {
        case .loading:
            // 끝나지 않는 이펙트 — 헤더가 빈 로딩 상태로 멈춰 있게 한다.
            values.loadProfileUseCase = LoadProfileUseCase(run: {
                try await Task.sleep(for: .seconds(60 * 60))
                throw SettingError.unknown
            })

        case .error:
            values.loadProfileUseCase = LoadProfileUseCase(run: {
                throw SettingError.network
            })

        default:
            values.loadProfileUseCase = .live(profile: StubProfileProvider())
        }
    }

    // MARK: - 테마

    /// 상태 분기가 없다 — 로컬 저장이라 실패 경로가 없고, 값이 즉시 돌아와 로딩 표시도 없다.
    /// 프로필이 `loading`·`error`여도 테마는 정상 표시된다(그게 프로필과 분리한 이유다).
    private static func registerTheme(
        settings: any SettingsRepository,
        into values: inout DependencyValues
    ) {
        values.loadThemeUseCase = .live(settings: settings)
        values.selectThemeUseCase = .live(settings: settings)
    }

    // MARK: - 알림

    private static func registerNotification(
        state: DemoLaunchArguments.State,
        settings: any SettingsRepository,
        into values: inout DependencyValues
    ) {
        // 기본값은 `.denied` — 시안(`ref_notification.png`)이 배너가 보이는 상태다.
        let permission = StubNotificationPermissionProvider(status: Self.authorizationStatus(for: state))

        values.loadNotificationSettingsUseCase = .live(settings: settings, permission: permission)
        values.updateServiceNotificationUseCase = .live(settings: settings)
        values.requestNotificationAuthorizationUseCase = .live(permission: permission)
        values.openSystemNotificationSettingsUseCase = .live(permission: permission)
    }

    /// `.notDetermined`와 `.denied`는 배너가 같지만 탭했을 때 갈리므로 인자로 구분한다.
    private static func authorizationStatus(
        for state: DemoLaunchArguments.State
    ) -> NotificationAuthorizationStatus {
        switch state {
        case .permissionOn: .authorized
        case .permissionNotDetermined: .notDetermined
        default: .denied
        }
    }

    // MARK: - 계정

    private static func registerAccount(
        state: DemoLaunchArguments.State,
        into values: inout DependencyValues
    ) {
        let account = StubAccountRepository(failure: state == .error ? .network : nil)

        values.signOutUseCase = .live(account: account)
        values.deleteAccountUseCase = .live(account: account)
    }

    // MARK: - 외부 링크

    /// 실제로 Safari·App Store가 열리면 스크린샷 캡처 흐름이 끊긴다 — 호출 사실만 로그로 남긴다.
    ///
    /// 주소도 데모용으로 채운다. live는 아직 `nil`이라(주소 미확정) 그대로 두면
    /// 두 행을 눌러도 아무 것도 일어나지 않아 배선 자체를 확인할 수 없다.
    private static func registerExternalLinks(into values: inout DependencyValues) {
        values.settingExternalLinks = SettingExternalLinks(
            appStoreReview: { URL(string: "https://demo.challa/app-store-review") },
            feedbackForm: { URL(string: "https://demo.challa/feedback-form") }
        )
        values.openURL = OpenURLEffect { url in
            print("[Demo] 외부 링크 열기 요청: \(url)")
            return true
        }
    }
}
