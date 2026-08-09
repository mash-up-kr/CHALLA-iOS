import Foundation

/// 유저 프로필 흐름에서 Feature까지 전파되는 도메인 오류.
/// Data 레이어가 서버·전송 오류를 이 타입으로 정규화해 던진다.
public enum UserError: Error, Equatable, Sendable {
    case invalidNickname(NicknameRule.Violation)
    case network
    case unauthorized
    case server(message: String)
    case unknown

    // TODO: 아래 문구는 임의 작성본 — 기획 문구 확정 시 일괄 교체할 것.
    /// 토스트 본문.
    public var userMessage: String {
        switch self {
        case let .invalidNickname(violation): return violation.userMessage
        case .network: return "네트워크 연결을 확인해 주세요."
        case .unauthorized: return "인증에 실패했어요. 다시 시도해 주세요."
        case let .server(message): return message.isEmpty ? "프로필 저장에 실패했어요." : message
        case .unknown: return "알 수 없는 오류가 발생했어요."
        }
    }
}
