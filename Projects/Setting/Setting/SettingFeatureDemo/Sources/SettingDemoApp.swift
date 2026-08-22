import ComposableArchitecture
import SettingFeature
import SwiftUI

/// 설정 화면 데모앱.
///
/// 실행 인자로 화면·상태를 받아 그 상태로 바로 뜬다 (`DemoLaunchArguments` 참고).
///
/// ```bash
/// xcrun simctl launch booted <bundle-id> --screen setting --state error
/// xcrun simctl launch booted <bundle-id> --screen account --state drawerConfirm
/// ```
@main
struct SettingDemoApp: App {

    /// **Store는 여기서 딱 한 번 만든다.**
    /// `body`나 computed property 안에서 만들면 뷰가 다시 그려질 때마다 Store가 새로 생겨
    /// 진행 중이던 이펙트가 끊기고 상태가 초기화된다.
    @State private var store: StoreOf<SettingFeature>

    init() {
        let arguments = DemoLaunchArguments()
        AppThemeStorageKey.migrateIfNeeded()
        // State를 만들기 전에 덮어써야 첫 화면부터 인자값이 보인다.
        CompositionRoot.forceThemeIfRequested(arguments)
        _store = State(
            initialValue: Store(initialState: Self.initialState(for: arguments)) {
                SettingFeature()._printChanges()
            } withDependencies: {
                CompositionRoot.register(arguments: arguments, into: &$0)
            }
        )
    }

    var body: some Scene {
        WindowGroup {
            // 하위 화면도 이 뷰가 소유한 `NavigationStack`을 통해 그려진다 —
            // 데모는 `path`를 미리 채워 두기만 하고 화면을 직접 고르지 않는다.
            SettingView(store: store)
        }
    }

    // MARK: - 진입 상태

    /// `--screen`에 따라 하위 화면을 스택에 미리 쌓는다.
    private static func initialState(for arguments: DemoLaunchArguments) -> SettingFeature.State {
        var state = SettingFeature.State()

        switch arguments.screen {
        case .setting:
            break

        case .theme:
            state.path.append(.theme(ThemeFeature.State()))

        case .notification:
            state.path.append(.notification(NotificationSettingFeature.State()))

        case .account:
            state.path.append(.account(accountState(for: arguments.state)))
        }

        return state
    }

    /// 계정 관리 화면의 드로어는 상태를 직접 세팅해 띄운다 — 탭으로 열 수 없기 때문이다.
    ///
    /// 프로필은 부모 스냅샷이 아직 없어서 데모가 직접 넣는다 (`StubProfileProvider`와 같은 값).
    private static func accountState(for state: DemoLaunchArguments.State) -> AccountFeature.State {
        var accountState = AccountFeature.State(profile: StubProfileProvider.profile)

        switch state {
        case .drawerSignOut:
            accountState.drawer = .signOutConfirmation
        case .drawerConfirm:
            accountState.drawer = .deleteConfirmation
        case .drawerCompleted:
            accountState.drawer = .deleteCompleted
        default:
            break
        }

        return accountState
    }
}
