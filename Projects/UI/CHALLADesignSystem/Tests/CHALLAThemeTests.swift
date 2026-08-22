@testable import CHALLADesignSystem
import SwiftUI
import Testing

/// 테마 색 묶음과 Environment 키 테스트.
/// 실제 색이 화면에 어떻게 보이는지는 검수앱 갤러리에서 눈으로 검수한다.
struct CHALLAThemeTests {

    @Test("glow를 생략하면 accent를 쓴다")
    func glowFallsBackToAccent() {
        let theme = CHALLATheme(accent: CHALLAColor.Primary.pink)

        #expect(theme.glow == theme.accent)
    }

    @Test("주입이 없으면 레몬에이드다 — 프리뷰·검수앱이 배선 없이 그려지는 근거다")
    func defaultThemeIsLemonade() {
        #expect(EnvironmentValues().challaTheme == CHALLATheme.lemonade)
    }
}
