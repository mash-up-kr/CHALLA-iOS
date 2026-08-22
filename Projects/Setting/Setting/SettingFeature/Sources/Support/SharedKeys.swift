import ComposableArchitecture
import Foundation
import SettingDomain

public extension SharedKey where Self == AppStorageKey<AppTheme>.Default {

    /// 사용자가 고른 테마. 고른 적이 없으면 `AppTheme.default`.
    ///
    /// 설정 화면과 앱 루트가 이 값 하나를 함께 읽는다. 값을 넘겨주는 코드가 없어서
    /// 화면 구조가 바뀌어도 전달 경로가 끊기지 않는다.
    ///
    /// 키에 마침표를 쓰지 않는다 — KVO가 마침표를 키패스 구분자로 읽어 값 변경 관찰이 깨진다.
    /// 이전 구현이 쓰던 키는 `AppThemeStorageKey.migrateIfNeeded()`가 한 번 옮긴다.
    static var appTheme: Self {
        Self[.appStorage(AppThemeStorageKey.current), default: .default]
    }
}

// MARK: - AppThemeStorageKey

/// 테마 저장 키와 그 이전 키의 이사.
public enum AppThemeStorageKey {

    public static let current = "challaSettingTheme"

    /// 마침표 때문에 버린 이전 키.
    static let legacy = "challa.setting.theme"

    /// 이전 키에 남아 있는 선택을 새 키로 한 번 옮긴다. 앱 진입점에서 1회 호출한다.
    ///
    /// 새 키에 이미 값이 있으면 덮지 않는다 — 이사 후 사용자가 고른 값이 더 최신이다.
    /// 옮긴 뒤 이전 키를 지워서 두 번 실행돼도 결과가 같다.
    public static func migrateIfNeeded(in defaults: UserDefaults = .standard) {
        guard let stored = defaults.string(forKey: legacy) else { return }
        if defaults.string(forKey: current) == nil {
            defaults.set(stored, forKey: current)
        }
        defaults.removeObject(forKey: legacy)
    }
}
