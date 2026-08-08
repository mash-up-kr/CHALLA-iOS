import Foundation
import SettingDomain

/// `SettingsRepository`의 기본 구현 — 테마·알림을 기기에 저장한다.
///
/// 프로필은 여기서 다루지 않는다. 다른 aggregate라 `SettingProfileProvider`가 맡고,
/// 그 구현은 이슈 #33의 `UserRepository`가 들어온 뒤 합성 지점에서 연결한다.
public struct DefaultSettingsRepository: SettingsRepository {

    private enum Key {
        static let theme = "challa.setting.theme"
        static let serviceNotification = "challa.setting.notification.service"
    }

    private let storage: any SettingsStorage

    public init(storage: any SettingsStorage = UserDefaultsSettingsStorage()) {
        self.storage = storage
    }

    /// 저장된 문자열이 알 수 없는 값이면(앱 다운그레이드·수동 조작 등) 기본 테마로 떨어진다.
    public func fetchTheme() async -> AppTheme {
        guard
            let raw = storage.string(forKey: Key.theme),
            let theme = AppTheme(rawValue: raw)
        else {
            return .default
        }
        return theme
    }

    public func updateTheme(_ theme: AppTheme) async {
        storage.setString(theme.rawValue, forKey: Key.theme)
    }

    public func fetchNotificationSetting() async -> NotificationSetting {
        guard let isEnabled = storage.bool(forKey: Key.serviceNotification) else {
            return .default
        }
        return NotificationSetting(isServiceEnabled: isEnabled)
    }

    public func updateNotificationSetting(_ setting: NotificationSetting) async {
        storage.setBool(setting.isServiceEnabled, forKey: Key.serviceNotification)
    }
}
