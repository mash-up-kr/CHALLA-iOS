import Foundation

/// 채팅 흐름(조회·작성)에서 Feature까지 전파되는 도메인 오류.
/// Data 레이어가 자기 오류를 이 타입으로 정규화해 던진다 (`PhotoError`·`RoomError`와 같은 구조).
public enum ChatError: Error, Equatable, Sendable {

    /// 오프라인·타임아웃 등 전송 자체가 실패.
    case network

    /// 401 — 토큰 만료.
    case unauthorized

    /// 서버가 실패를 알림.
    case server(message: String)

    /// 그 외 분류 불가능한 오류.
    case unknown

    // TODO: 문구는 임의 작성본 — 기획의 에러 문구 가이드 확정 시 일괄 교체.
    public var userMessage: String {
        switch self {
        case .network: "네트워크 연결을 확인해 주세요."
        case .unauthorized: "다시 로그인해 주세요."
        case let .server(message): message.isEmpty ? "잠시 후 다시 시도해 주세요." : message
        case .unknown: "알 수 없는 오류가 발생했어요."
        }
    }
}
