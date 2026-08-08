@testable import SettingData
import SettingDomain
import Testing
import UserNotifications

/// `SystemNotificationPermissionProvider`의 OS 상태 → Domain 상태 매핑.
/// 순수 함수라 권한 팝업 없이 검증한다.
struct NotificationPermissionMappingTests {

    @Test(
        "OS 권한 상태를 화면이 쓰는 세 가지로 접는다",
        arguments: [
            (UNAuthorizationStatus.notDetermined, NotificationAuthorizationStatus.notDetermined),
            (.denied, .denied),
            (.authorized, .authorized),
            // 조용한 알림·앱 클립도 알림이 오는 상태다 — "꺼져있어요" 배너를 띄우면 안 된다.
            (.provisional, .authorized),
            (.ephemeral, .authorized)
        ]
    )
    func mapsKnownStatus(
        status: UNAuthorizationStatus,
        expected: NotificationAuthorizationStatus
    ) {
        #expect(SystemNotificationPermissionProvider.mapped(status) == expected)
    }

    @Test("모르는 상태는 꺼짐으로 본다 — 알림이 온다고 가정하지 않는다")
    func mapsUnknownStatusToDenied() throws {
        // OS에 새 상태가 추가된 상황을 흉내낸다 (`@unknown default` 경로).
        let future = try #require(UNAuthorizationStatus(rawValue: 99))

        #expect(SystemNotificationPermissionProvider.mapped(future) == .denied)
    }
}
