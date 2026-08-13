import CHALLADesignSystem
import SwiftUI

@main
struct ProfileSetupDemoApp: App {

    init() {
        CHALLAFontRegister.register()
    }

    var body: some Scene {
        WindowGroup {
            DemoRootView()
        }
    }
}
