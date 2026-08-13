import Foundation
import SettingDomain

/// 데모용 알림 권한 공급자 — 권한 상태를 실행 인자로 못 박는다.
///
/// **실 구현(`SystemNotificationPermissionProvider`)을 쓰지 않는 이유**: 시뮬레이터의 권한 상태에
/// 따라 배너가 있다 없다 해서 시안 대조 검증이 흔들린다. 실 구현 확인은 `CHALLAApp` 조립 후에 한다.
///
/// 설정 앱 열기도 아무 것도 하지 않는다 — 실제로 설정 앱이 열리면 스크린샷 캡처 흐름이 끊긴다.
struct StubNotificationPermissionProvider: NotificationPermissionProvider {

    let status: NotificationAuthorizationStatus

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        status
    }

    func openSystemNotificationSettings() async {
        print("[Demo] 설정 앱 열기 요청 (스텁이라 실제로 열지 않는다)")
    }
}
