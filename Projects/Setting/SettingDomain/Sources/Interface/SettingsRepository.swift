import Foundation

/// 테마·알림 설정의 저장소 추상. 구현은 `SettingData`가 맡는다.
///
/// 프로필은 여기 없다 — 다른 aggregate라 `SettingProfileProvider`가 따로 맡는다 (그쪽 주석 참고).
///
/// 테마·알림은 기기에 저장되므로 실패 개념이 없어 던지지 않는다.
public protocol SettingsRepository: Sendable {

    /// 저장된 테마를 읽는다. 고른 적이 없으면 `AppTheme.default`.
    /// 로컬 저장이라 실패 개념이 없어 던지지 않는다.
    func fetchTheme() async -> AppTheme

    func updateTheme(_ theme: AppTheme) async

    /// 저장된 알림 설정을 읽는다. 설정한 적이 없으면 `NotificationSetting.default`.
    func fetchNotificationSetting() async -> NotificationSetting

    func updateNotificationSetting(_ setting: NotificationSetting) async
}
