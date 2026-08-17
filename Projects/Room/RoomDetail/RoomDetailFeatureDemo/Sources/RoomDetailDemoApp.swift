import ComposableArchitecture
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
                LaunchScreenView(screen: launchScreen)
            } else {
                DemoRootView()
            }
        }
    }
}

/// 실행 인자로 지정된 화면.
///
/// 스토어를 `@State`로 한 번만 만든다. `WindowGroup` 안에서 바로 만들면 화면이 다시 평가될 때마다
/// 새 스토어가 생겨 조회 결과가 초기화되고 이미지 로드도 처음부터 다시 시작한다
/// (`DemoRootView`의 화면도 같은 이유로 `@State`를 쓴다).
private struct LaunchScreenView: View {

    @State private var store: StoreOf<RoomDetailFeature>

    init(screen: DemoScreen) {
        _store = State(initialValue: DemoStore.make(for: screen))
    }

    var body: some View {
        RoomDetailView(store: store)
    }
}
