@testable import SettingFeature
import SettingDomain
import Testing

/// `AppTheme` → 색 매핑 테스트.
/// 색이 시안과 맞는지는 눈으로 검수하고, 여기서는 6개 case가 겹치거나 빠지지 않는지만 고정한다.
struct AppThemeColorTests {

    @Test("여섯 테마의 강조 색이 서로 다르다 — 매핑이 빠지거나 겹치면 잡힌다")
    func everyThemeHasItsOwnAccent() {
        let accents = AppTheme.allCases.map(\.themeColor)

        #expect(Set(accents).count == AppTheme.allCases.count)
    }
}
