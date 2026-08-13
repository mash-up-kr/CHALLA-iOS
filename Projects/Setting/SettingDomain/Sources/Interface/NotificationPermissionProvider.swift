import Foundation

/// 시스템 알림 권한 조회·요청과 설정 앱 이동.
///
/// OS를 만지는 일이라 구현은 Feature 밖(`SettingData`)에 둔다 —
/// Domain은 모양만 정의한다 (`SettingProfileProvider`와 같은 패턴).
public protocol NotificationPermissionProvider: Sendable {

    /// 현재 권한 상태를 읽는다. 권한을 **요청하지는 않는다**.
    func authorizationStatus() async -> NotificationAuthorizationStatus

    /// 시스템 알림 권한을 요청하고, 요청이 끝난 뒤의 상태를 돌려준다.
    ///
    /// `.notDetermined`에서만 OS가 팝업을 띄운다. 이미 정해진 상태에서는 팝업 없이
    /// 현재 상태가 그대로 돌아온다 — 호출부가 상태를 먼저 확인하지 않아도 안전하다.
    func requestAuthorization() async -> NotificationAuthorizationStatus

    /// iOS 설정 앱의 이 앱 화면을 연다.
    /// 열지 못하면 조용히 무시한다 — 사용자에게 알릴 문구가 시안에 없다.
    func openSystemNotificationSettings() async
}
