@testable import SettingDomain
import Testing

struct AppThemeTests {

    @Test("테마는 기획이 정한 6종이다")
    func themeCount() {
        #expect(AppTheme.allCases.count == 6)
    }

    @Test("기본 테마는 레몬에이드다")
    func defaultTheme() {
        #expect(AppTheme.default == .lemonade)
    }

    @Test(
        "표시 이름이 시안 문구와 일치한다",
        arguments: [
            (AppTheme.lemonade, "레몬에이드"),
            (.raspberry, "라즈베리"),
            (.orange, "오렌지"),
            (.cider, "사이다"),
            (.blueberry, "블루베리"),
            (.acaiBowl, "아사이볼")
        ]
    )
    func displayName(theme: AppTheme, expected: String) {
        #expect(theme.displayName == expected)
    }

    @Test("표시 이름은 테마마다 다르다 — 설정 화면에서 값으로 구분되어야 한다")
    func displayNamesAreUnique() {
        let names = Set(AppTheme.allCases.map(\.displayName))
        #expect(names.count == AppTheme.allCases.count)
    }

    @Test("rawValue로 왕복 변환된다 — 로컬 저장에 rawValue를 쓴다")
    func rawValueRoundTrip() {
        for theme in AppTheme.allCases {
            #expect(AppTheme(rawValue: theme.rawValue) == theme)
        }
    }
}
