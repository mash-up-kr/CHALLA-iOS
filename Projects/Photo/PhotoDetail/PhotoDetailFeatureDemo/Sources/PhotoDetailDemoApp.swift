import CHALLADesignSystem
import SwiftUI

/// PhotoDetailFeature 데모앱 진입점.
@main
struct PhotoDetailDemoApp: App {

    init() {
        CHALLAFontRegister.register()
    }

    var body: some Scene {
        WindowGroup {
            DemoRootView()
        }
    }
}
