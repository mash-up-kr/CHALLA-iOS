import Foundation
import SettingDomain

/// 실행 인자로 못 박은 값만 **읽기에서** 가로채는 데코레이터 (`--serviceNotification`).
///
/// 저장은 언제나 실제 저장소로 흘려보낸다 — 화면에서 값을 바꿨을 때의 동작을 그대로 보고 싶다.
///
/// 이게 없으면 이전 실행에서 저장된 값이 인자를 이겨서 같은 명령이 매번 다른 화면을 만든다
/// (알림 저장은 데모에서도 실제 `UserDefaults`를 쓴다).
/// 알림 화면은 `onAppear`에서 저장값으로 상태를 확정하므로, State를 미리 채우는 것만으로는
/// 첫 프레임 뒤에 값이 되돌아간다.
///
/// 테마는 여기 없다. `@Shared`가 저장소를 직접 읽어서 이 데코레이터로 가로챌 수 없고,
/// 대신 `CompositionRoot.forceThemeIfRequested(_:)`가 저장값을 미리 덮어쓴다.
struct ForcedSettingsRepository: SettingsRepository {

    let base: any SettingsRepository

    let isServiceNotificationEnabled: Bool

    func fetchNotificationSetting() async -> NotificationSetting {
        NotificationSetting(isServiceEnabled: isServiceNotificationEnabled)
    }

    func updateNotificationSetting(_ setting: NotificationSetting) async {
        await base.updateNotificationSetting(setting)
    }
}
