@testable import SettingDomain
import Foundation

/// 테스트용 알림 권한 공급자. 권한 상태를 생성 시점에 정한다.
struct MockNotificationPermissionProvider: NotificationPermissionProvider {

    private let status: NotificationAuthorizationStatus

    init(status: NotificationAuthorizationStatus = .authorized) {
        self.status = status
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        status
    }

    func openSystemNotificationSettings() async {}
}
