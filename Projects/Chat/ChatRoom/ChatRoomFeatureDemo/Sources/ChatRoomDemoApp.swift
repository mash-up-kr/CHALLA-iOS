import CHALLADesignSystem
import SwiftUI

/// ChatRoomFeature 데모앱 진입점.
@main
struct ChatRoomDemoApp: App {

    init() {
        CHALLAFontRegister.register()
    }

    var body: some Scene {
        WindowGroup {
            DemoRootView()
        }
    }
}
