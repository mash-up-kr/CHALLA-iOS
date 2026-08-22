@testable import SettingFeature
import ComposableArchitecture
import Foundation
import SettingDomain
import Testing

/// 이전 키에 남은 테마를 새 키로 옮기는 마이그레이션 테스트.
struct AppThemeStorageKeyTests {

    /// 테스트마다 새 suite를 써서 서로 상태가 새지 않게 한다.
    private func makeDefaults() -> UserDefaults {
        .inMemory
    }

    @Test("이전 키의 값을 새 키로 옮기고 이전 키를 지운다")
    func movesLegacyValue() {
        let defaults = makeDefaults()
        defaults.set(AppTheme.blueberry.rawValue, forKey: AppThemeStorageKey.legacy)

        AppThemeStorageKey.migrateIfNeeded(in: defaults)

        #expect(defaults.string(forKey: AppThemeStorageKey.current) == AppTheme.blueberry.rawValue)
        #expect(defaults.string(forKey: AppThemeStorageKey.legacy) == nil)
    }

    @Test("새 키에 이미 값이 있으면 덮지 않는다 — 이사 뒤에 고른 값이 더 최신이다")
    func keepsNewerValue() {
        let defaults = makeDefaults()
        defaults.set(AppTheme.blueberry.rawValue, forKey: AppThemeStorageKey.legacy)
        defaults.set(AppTheme.orange.rawValue, forKey: AppThemeStorageKey.current)

        AppThemeStorageKey.migrateIfNeeded(in: defaults)

        #expect(defaults.string(forKey: AppThemeStorageKey.current) == AppTheme.orange.rawValue)
        #expect(defaults.string(forKey: AppThemeStorageKey.legacy) == nil)
    }

    @Test("두 번 실행해도 결과가 같다 — 앱이 여러 번 켜져도 안전하다")
    func isIdempotent() {
        let defaults = makeDefaults()
        defaults.set(AppTheme.cider.rawValue, forKey: AppThemeStorageKey.legacy)

        AppThemeStorageKey.migrateIfNeeded(in: defaults)
        AppThemeStorageKey.migrateIfNeeded(in: defaults)

        #expect(defaults.string(forKey: AppThemeStorageKey.current) == AppTheme.cider.rawValue)
    }
}
