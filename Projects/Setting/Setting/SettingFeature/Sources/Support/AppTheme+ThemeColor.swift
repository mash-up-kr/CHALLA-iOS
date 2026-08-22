import CHALLADesignSystem
import SettingDomain
import SwiftUI

public extension AppTheme {

    /// 테마의 색. 시안(`ref_theme.png`)의 점 색과 일치를 확인했다.
    ///
    /// 앱 루트가 이 값을 `\.challaTheme`에 주입한다.
    /// Domain은 UI를, DS는 Domain을 모르므로 둘 다 아는 Feature가 매핑을 갖는다.
    var palette: CHALLATheme {
        // 하단 번짐은 테마를 따르지 않고 브랜드 색으로 고정한다.
        CHALLATheme(accent: themeColor, glow: CHALLAColor.Background.brand)
    }

    /// 이 테마의 강조 색. 테마 목록의 점처럼 고르지 않은 테마까지 나란히 그릴 때 쓴다.
    /// 현재 적용된 테마 색이 필요하면 `@Environment(\.challaTheme)`를 읽는다.
    var themeColor: Color {
        switch self {
        case .lemonade: CHALLAColor.Primary.yellow
        case .raspberry: CHALLAColor.Primary.pink
        case .orange: CHALLAColor.Primary.orange
        case .cider: CHALLAColor.Primary.sky
        case .blueberry: CHALLAColor.Primary.blue
        case .acaiBowl: CHALLAColor.Primary.purple
        }
    }
}
