import Foundation

/// 실행 인자로 화면과 상태를 지정한다. 시뮬레이터를 탭으로 조작할 수 없어, 인자로 원하는 화면을 바로 띄운다.
///
/// ```bash
/// xcrun simctl launch booted com.challa.photodetailfeature.demo --screen photo-detail --state empty
/// ```
struct DemoLaunchArguments: Equatable {

    enum Screen: String {
        case photoDetail = "photo-detail"
    }

    enum State: String, CaseIterable {
        /// 사진 5장.
        case `default`
        /// 목록을 불러오는 중에서 멈춘 상태.
        case loading
        case empty
        case error
    }

    /// 지정하지 않으면 어떤 화면을 띄울지 고르는 목록을 보여준다.
    let screen: Screen?
    let state: State

    static func parse(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> Self {
        DemoLaunchArguments(
            screen: value(of: "--screen", in: arguments).flatMap(Screen.init(rawValue:)),
            state: value(of: "--state", in: arguments).flatMap(State.init(rawValue:)) ?? .default
        )
    }

    private static func value(of name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}
