import Foundation
import SettingDomain

/// 데모용 알림 권한 공급자 — 권한 상태를 실행 인자로 못 박는다.
///
/// **실 구현(`SystemNotificationPermissionProvider`)을 쓰지 않는 이유**: 시뮬레이터의 권한 상태에
/// 따라 배너가 있다 없다 해서 시안 대조 검증이 흔들린다. 실 구현 확인은 `CHALLAApp`에서 한다.
///
/// 권한 요청도 실제로 팝업을 띄우지 않는다 — OS 팝업이 뜨면 스크린샷 캡처 흐름이 끊기고,
/// 시뮬레이터는 한 번 답하면 되돌릴 수 없어 같은 인자가 다른 결과를 낸다.
/// 설정 앱 열기도 같은 이유로 아무 것도 하지 않는다.
struct StubNotificationPermissionProvider: NotificationPermissionProvider {

    let status: NotificationAuthorizationStatus

    /// 권한 요청 후 돌려줄 상태. `--state permissionNotDetermined`에서 배너 탭 흐름을 보려고 둔다.
    let statusAfterRequest: NotificationAuthorizationStatus

    init(
        status: NotificationAuthorizationStatus,
        statusAfterRequest: NotificationAuthorizationStatus = .authorized
    ) {
        self.status = status
        self.statusAfterRequest = statusAfterRequest
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        status
    }

    func requestAuthorization() async -> NotificationAuthorizationStatus {
        print("[Demo] 알림 권한 요청 (스텁이라 팝업을 띄우지 않고 \(statusAfterRequest)를 돌려준다)")
        return statusAfterRequest
    }

    func openSystemNotificationSettings() async {
        print("[Demo] 설정 앱 열기 요청 (스텁이라 실제로 열지 않는다)")
    }
}
