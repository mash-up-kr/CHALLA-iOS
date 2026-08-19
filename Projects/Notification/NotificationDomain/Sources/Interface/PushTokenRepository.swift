import Foundation

/// FCM 디바이스 토큰을 서버에 등록·해제한다 (구현: `NotificationData`).
///
/// 서버는 토큰이 등록된 기기에만 푸시를 보낸다.
/// 알림을 켜고 끄는 설정 API가 따로 없어서, '서비스 알림' 토글도 이 등록·해제로 처리한다.
///
/// 구현체는 모든 실패를 `NotificationError`로 바꿔 던진다.
public protocol PushTokenRepository: Sendable {

    /// 이 기기의 FCM 토큰을 내 계정에 등록한다. 같은 토큰을 다시 등록해도 안전하다.
    func register(token: String) async throws

    /// 등록을 해제한다. 로그아웃·탈퇴·알림 끄기에서 호출한다.
    ///
    /// 해제하지 않으면 같은 기기에 다른 계정으로 로그인해도 이전 계정의 푸시가 온다.
    func unregister(token: String) async throws

    #if DEBUG
        /// 내 계정에 등록된 토큰 전부로 테스트 푸시를 보내고, 전송에 성공한 토큰 수를 돌려준다.
        ///
        /// **개발 중 수신 확인용이라 릴리스 빌드에는 넣지 않는다.**
        /// `0`이면 등록된 토큰이 없다는 뜻이라 등록 성공 여부를 이걸로 판별한다.
        func sendTestPush(title: String, body: String) async throws -> Int
    #endif
}
