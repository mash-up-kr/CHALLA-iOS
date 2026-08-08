import CHALLADesignSystem
import SettingDomain
import SwiftUI

public extension AppTheme {

    /// 테마의 포인트 색. 시안(`ref_theme.png`)의 점 색과 일치를 확인했다.
    ///
    /// Domain은 UI를, DS는 Domain을 모르므로 둘 다 아는 Feature가 매핑을 갖는다.
    /// 앱 전체 테마 적용이 생기면 공용 위치로 승격한다.
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
