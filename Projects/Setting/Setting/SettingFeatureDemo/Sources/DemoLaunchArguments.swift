import Foundation

/// 데모앱이 실행 인자로 받는 진입 지점.
///
/// 시뮬레이터를 탭으로 조작할 수 없어서, 시안 검증(`zeplin-ui-verification`)은
/// 화면과 상태를 인자로 직접 띄워 캡처한다.
///
/// ```bash
/// xcrun simctl launch booted <bundle-id> --screen setting --state default
/// ```
///
/// 인자를 주지 않으면 기본값(`setting` / `default`)으로 뜬다.
struct DemoLaunchArguments: Equatable {

    /// 데모앱 안에서 띄울 화면.
    enum Screen: String {
        case setting
    }

    /// 그 화면의 상태. 시안에 정의된 상태를 전부 인자로 띄울 수 있어야 한다.
    enum State: String {
        /// 정상적으로 불러온 상태.
        case `default`
        /// 불러오는 중 — 헤더와 테마 값이 비어 있다.
        case loading
        /// 불러오기 실패 — 얼럿이 뜬다.
        case error
    }

    var screen: Screen = .setting
    var state: State = .default

    /// `--screen <값>` · `--state <값>` 형태를 읽는다.
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
