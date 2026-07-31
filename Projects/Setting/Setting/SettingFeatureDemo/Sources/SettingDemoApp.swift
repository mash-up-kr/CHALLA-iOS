import ComposableArchitecture
import SettingFeature
import SwiftUI

/// 설정 화면 데모앱.
///
/// 실행 인자로 화면·상태를 받아 그 상태로 바로 뜬다 (`DemoLaunchArguments` 참고).
///
/// ```bash
/// xcrun simctl launch booted <bundle-id> --screen setting --state error
/// ```
@main
struct SettingDemoApp: App {

    private let arguments: DemoLaunchArguments

    /// **Store는 여기서 딱 한 번 만든다.**
    /// `body`나 computed property 안에서 만들면 뷰가 다시 그려질 때마다 Store가 새로 생겨
    /// 진행 중이던 이펙트가 끊기고 상태가 초기화된다.
    @State private var store: StoreOf<SettingFeature>

    init() {
        let arguments = DemoLaunchArguments()
        self.arguments = arguments
        _store = State(
            initialValue: Store(initialState: SettingFeature.State()) {
                SettingFeature()._printChanges()
            } withDependencies: {
                CompositionRoot.register(state: arguments.state, into: &$0)
            }
        )
    }

    var body: some Scene {
        WindowGroup {
            switch arguments.screen {
            case .setting:
                SettingView(store: store)
            }
        }
    }
}
