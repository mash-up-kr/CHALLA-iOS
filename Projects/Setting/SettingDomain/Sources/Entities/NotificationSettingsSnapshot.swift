import Foundation

/// 시스템(iOS)이 이 앱에 준 알림 권한 상태.
///
/// `UNAuthorizationStatus`를 그대로 쓰지 않고 화면이 필요로 하는 세 가지로 좁힌다 —
/// Domain은 `UserNotifications`를 모른다(그걸 아는 건 `SettingData`의 구현체다).
public enum NotificationAuthorizationStatus: Sendable, Equatable {

    /// 아직 권한을 물어본 적 없다.
    case notDetermined

    /// 사용자가 껐다.
    case denied

    /// 허용. `provisional`·`ephemeral`도 여기로 접는다 (알림이 어떤 형태로든 오는 상태라서).
    case authorized
}

/// 알림 화면이 한 번에 필요로 하는 값 묶음.
///
/// 저장값(로컬)과 권한(OS)을 각각 불러오면 화면이 두 번 갱신되어 깜빡인다 —
/// `SettingsSnapshot`과 같은 이유로 한 번에 모아 돌려준다.
public struct NotificationSettingsSnapshot: Sendable, Equatable {

    public let setting: NotificationSetting
    public let authorization: NotificationAuthorizationStatus

    public init(setting: NotificationSetting, authorization: NotificationAuthorizationStatus) {
        self.setting = setting
        self.authorization = authorization
    }
}
