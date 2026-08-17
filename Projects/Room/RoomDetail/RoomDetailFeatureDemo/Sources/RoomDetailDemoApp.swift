import RoomDetailFeature
import SwiftUI

/// RoomDetailFeature 데모앱 진입점.
///
/// 실행 인자로 화면을 지정하면 그 화면만 바로 띄우고(시안 대조 검증용),
/// 인자가 없으면 화면을 골라 들어가는 목록을 띄운다(사람이 눌러볼 때).
@main
struct RoomDetailDemoApp: App {

    /// 앱이 뜬 뒤로는 바뀌지 않는 값이라 한 번만 읽는다.
    private let launchScreen = DemoScreen.parse()

    var body: some Scene {
        WindowGroup {
            if let launchScreen {
                RoomDetailView(store: DemoStore.make(for: launchScreen))
            } else {
                DemoRootView()
            }
        }
    }
}
