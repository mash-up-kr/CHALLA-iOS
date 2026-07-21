import CHALLADesignSystem
import SwiftUI

@main
struct CHALLADesignSystemApp: App {
    init() {
        // 앱 시작 시 커스텀 폰트(SUIT/Dirtyline)를 iOS에 등록한다.
        CHALLAFontRegister.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
