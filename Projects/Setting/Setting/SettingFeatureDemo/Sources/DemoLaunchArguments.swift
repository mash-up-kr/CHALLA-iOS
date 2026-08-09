import Foundation
import SettingDomain

/// 데모앱이 실행 인자로 받는 진입 지점.
///
/// 시뮬레이터를 탭으로 조작할 수 없어서, 시안 검증(`zeplin-ui-verification`)은
/// 화면과 상태를 인자로 직접 띄워 캡처한다.
///
/// ```bash
/// xcrun simctl launch booted <bundle-id> --screen setting --state default
/// xcrun simctl launch booted <bundle-id> --screen theme --theme raspberry
/// xcrun simctl launch booted <bundle-id> --screen notification --state permissionOff --serviceNotification on
/// xcrun simctl launch booted <bundle-id> --screen account --state drawerConfirm
/// ```
///
/// 인자를 주지 않으면 기본값(`setting` / `default` / `lemonade`)으로 뜬다.
struct DemoLaunchArguments: Equatable {

    /// 데모앱 안에서 띄울 화면. 설정 메인 외 셋은 `path`에 미리 쌓아 바로 보여준다.
    enum Screen: String {
        case setting
        case theme
        case notification
        case account
    }

    /// 그 화면의 상태. 시안에 정의된 상태를 전부 인자로 띄울 수 있어야 한다.
    ///
    /// 화면별로 나누지 않고 **합집합**으로 둔다 — 해당 화면에서 의미 없는 값이 오면
    /// 그 화면은 기본 모습으로 뜬다 (기존 파싱 정책과 동일: 잘못된 인자로 앱을 죽이지 않는다).
    enum State: String {
        /// 정상적으로 불러온 상태.
        case `default`
        /// 불러오는 중 — 헤더와 테마 값이 비어 있다. (setting)
        case loading
        /// 실패 — 얼럿이 뜬다. (setting · account)
        case error
        /// 시스템 알림 권한이 꺼져 있다 — 배너가 보인다. 시안의 상태다. (notification)
        case permissionOff
        /// 시스템 알림 권한이 켜져 있다 — 배너가 없다. (notification)
        case permissionOn
        /// 로그아웃 확인 드로어가 떠 있다. (account)
        case drawerSignOut
        /// 탈퇴 확인 드로어(A)가 떠 있다. (account)
        case drawerConfirm
        /// 탈퇴 완료 드로어(B)가 떠 있다. (account)
        case drawerCompleted
    }

    var screen: Screen = .setting
    var state: State = .default

    /// 테마 화면의 체크 위치와 알림 토글 ON 색을 시안대로 재현하는 데 쓴다.
    var theme: AppTheme = .default

    /// `--theme`가 실제로 주어졌는지.
    ///
    /// 주어졌으면 저장값(이전 실행에서 남은 선택)보다 인자를 우선한다 —
    /// 그래야 같은 명령이 항상 같은 화면을 만든다.
    var hasExplicitTheme = false

    /// 서비스 알림 토글의 초기값. `nil`이면 저장값을 그대로 쓴다.
    ///
    /// 권한(`--state permissionOn|permissionOff`)과 별개다 — 시스템 권한이 꺼져 있어도
    /// 서비스 알림 토글은 켜져 있을 수 있고, 시안에 두 상태가 모두 있다.
    var serviceNotification: Bool?

    /// `--screen <값>` · `--state <값>` · `--theme <값>` · `--serviceNotification <on|off>` 형태를 읽는다.
    /// 알 수 없는 값이 오면 조용히 기본값을 쓴다 — 검증 중 앱이 죽으면 원인 파악이 더 어려워진다.
    init(arguments: [String] = CommandLine.arguments) {
        if let raw = Self.value(for: "--screen", in: arguments),
           let screen = Screen(rawValue: raw) {
            self.screen = screen
        }
        if let raw = Self.value(for: "--state", in: arguments),
           let state = State(rawValue: raw) {
            self.state = state
        }
        if let raw = Self.value(for: "--theme", in: arguments),
           let theme = AppTheme(rawValue: raw) {
            self.theme = theme
            self.hasExplicitTheme = true
        }
        if let raw = Self.value(for: "--serviceNotification", in: arguments) {
            serviceNotification = Self.onOff(raw)
        }
    }

    /// 지금 띄우는 화면의 상태만 유효하게 본다.
    ///
    /// `State`가 모든 화면의 합집합이라, 그대로 쓰면 한 인자가 여러 화면에 동시에 걸린다 —
    /// 예컨대 `--screen account --state error`가 설정 메인까지 실패시켜
    /// 캡처하려던 계정 화면이 루트 얼럿에 가린다.
    func state(of screen: Screen) -> State {
        self.screen == screen ? state : .default
    }

    /// `on` · `off`만 받는다. 그 밖의 값은 `nil`(저장값 사용)로 흘린다.
    private static func onOff(_ raw: String) -> Bool? {
        switch raw {
        case "on": true
        case "off": false
        default: nil
        }
    }

    private static func value(for flag: String, in arguments: [String]) -> String? {
        guard
            let index = arguments.firstIndex(of: flag),
            arguments.indices.contains(index + 1)
        else {
            return nil
        }
        return arguments[index + 1]
    }
}
