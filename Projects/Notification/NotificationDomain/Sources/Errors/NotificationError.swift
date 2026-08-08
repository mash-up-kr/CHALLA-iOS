import Foundation

/// 푸시 토큰 등록·해제가 실패하는 방식. `NotificationData`가 모든 오류를 이 타입으로 바꿔 던진다.
///
/// 사용자에게 보여줄 일이 없어 `userMessage`를 두지 않는다.
/// 토큰 등록은 화면 없이 도는 동작이고, 실패하면 다음 앱 실행에서 다시 시도한다.
public enum NotificationError: Error, Equatable, Sendable {

    /// 서버에 닿지 못했다 (연결 끊김·타임아웃 등).
    case network

    /// 토큰이 만료됐거나 로그인 상태가 아니다.
    case unauthorized

    case server(message: String)

    case unknown
}
