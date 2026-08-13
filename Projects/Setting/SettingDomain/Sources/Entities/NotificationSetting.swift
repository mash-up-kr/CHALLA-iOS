import Foundation

/// 알림 수신 설정.
///
/// 현재 시안에 있는 항목은 `서비스 알림`(인화 대기·인화 완료 등) 하나뿐이다.
/// 항목이 늘어날 것을 대비해 Bool 하나가 아니라 구조체로 둔다.
public struct NotificationSetting: Sendable, Equatable, Codable {

    /// 인화 대기·인화 완료 등 서비스 알림 수신 여부.
    public var isServiceEnabled: Bool

    public init(isServiceEnabled: Bool) {
        self.isServiceEnabled = isServiceEnabled
    }

    /// 한 번도 설정한 적 없는 사용자에게 적용되는 값.
    /// 시안의 기본 상태가 OFF라 그대로 따른다.
    public static let `default` = NotificationSetting(isServiceEnabled: false)
}
