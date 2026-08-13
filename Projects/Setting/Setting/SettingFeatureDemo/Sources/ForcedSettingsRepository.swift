import Foundation
import SettingDomain

/// 실행 인자로 못 박은 값만 **읽기에서** 가로채는 데코레이터 (`--theme` · `--serviceNotification`).
///
/// 저장은 언제나 실제 저장소로 흘려보낸다 — 화면에서 값을 바꿨을 때의 동작을 그대로 보고 싶다.
///
/// 이게 없으면 이전 실행에서 저장된 값이 인자를 이겨서 같은 명령이 매번 다른 화면을 만든다
/// (테마·알림 저장은 데모에서도 실제 `UserDefaults`를 쓴다).
/// 특히 두 화면 모두 `onAppear`에서 저장값으로 상태를 확정하므로, State를 미리 채우는 것만으로는
/// 첫 프레임 뒤에 값이 되돌아간다.
struct ForcedSettingsRepository: SettingsRepository {

    let base: any SettingsRepository

    /// `nil`이면 저장값을 그대로 읽는다.
    let theme: AppTheme?

    /// `nil`이면 저장값을 그대로 읽는다.
    let isServiceNotificationEnabled: Bool?

    func fetchTheme() async -> AppTheme {
        guard let theme else { return await base.fetchTheme() }
        return theme
    }

    func updateTheme(_ theme: AppTheme) async {
        await base.updateTheme(theme)
    }

    func fetchNotificationSetting() async -> NotificationSetting {
        guard let isServiceNotificationEnabled else { return await base.fetchNotificationSetting() }
        return NotificationSetting(isServiceEnabled: isServiceNotificationEnabled)
    }

    func updateNotificationSetting(_ setting: NotificationSetting) async {
        await base.updateNotificationSetting(setting)
    }
}
