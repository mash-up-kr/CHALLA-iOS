@testable import SettingDomain
import Foundation

/// 테스트용 알림 권한 공급자. 권한 상태를 생성 시점에 정한다.
struct MockNotificationPermissionProvider: NotificationPermissionProvider {

    private let status: NotificationAuthorizationStatus

    /// 권한 요청이 끝난 뒤 돌려줄 상태. 넘기지 않으면 요청해도 상태가 그대로다.
    private let statusAfterRequest: NotificationAuthorizationStatus

    init(
        status: NotificationAuthorizationStatus = .authorized,
        statusAfterRequest: NotificationAuthorizationStatus? = nil
    ) {
        self.status = status
        self.statusAfterRequest = statusAfterRequest ?? status
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        status
    }

    func requestAuthorization() async -> NotificationAuthorizationStatus {
        statusAfterRequest
    }

    func openSystemNotificationSettings() async {}
}
