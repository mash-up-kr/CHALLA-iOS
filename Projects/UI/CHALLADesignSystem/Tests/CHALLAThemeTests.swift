@testable import CHALLADesignSystem
import SwiftUI
import Testing

struct CHALLAThemeTests {

    @Test("주입이 없으면 레몬에이드다 — 프리뷰·검수앱이 배선 없이 그려지는 근거다")
    func defaultThemeIsLemonade() {
        #expect(EnvironmentValues().challaTheme == CHALLATheme.lemonade)
    }
}
