import Foundation

/// 시스템 알림 권한 조회와 설정 앱 이동.
///
/// OS를 만지는 일이라 구현은 Feature 밖(`SettingData`)에 둔다 —
/// Domain은 모양만 정의한다 (`SettingProfileProvider`와 같은 패턴).
///
/// > 지금은 `SettingData`에 구현체가 있다. 푸시 등록 이슈에서 같은
/// > `UNUserNotificationCenter` 접근이 두 번째로 필요해지면 Core 모듈로 승격한다.
/// > 그때도 이 인터페이스는 그대로라 Feature는 손대지 않는다.
public protocol NotificationPermissionProvider: Sendable {

    /// 현재 권한 상태를 읽는다. 권한을 **요청하지는 않는다**.
    func authorizationStatus() async -> NotificationAuthorizationStatus

    /// iOS 설정 앱의 이 앱 화면을 연다.
    /// 열지 못하면 조용히 무시한다 — 사용자에게 알릴 문구가 시안에 없다.
    func openSystemNotificationSettings() async
}
