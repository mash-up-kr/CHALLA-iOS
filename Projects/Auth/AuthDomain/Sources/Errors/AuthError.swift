import Foundation

/// 인증 흐름에서 Feature까지 전파되는 도메인 오류.
///
/// Data 레이어가 `NetworkError`·소셜 SDK 오류를 이 타입으로 정규화해 던진다
/// (매핑 구현은 `AuthData` — Domain은 서버·SDK 오류 타입의 존재를 모른다.
public enum AuthError: Error, Equatable, Sendable {

    /// 사용자가 소셜 로그인을 직접 취소함 → 얼럿을 띄우지 않는다.
    case cancelled

    /// 오프라인·타임아웃 등 전송 자체가 실패.
    case network

    /// 401 (토큰 무효/만료).
    case unauthorized

    /// 서버가 실패를 알림 (`BaseResponse.success == false` 또는 4xx/5xx 메시지).
    case server(message: String)

    /// 소셜 SDK 자체 실패 (idToken 미발급 등).
    case social(reason: String)

    /// 그 외 분류 불가능한 오류.
    case unknown

    /// 얼럿 메시지 (디자인에 상세 화면이 없으므로 최소 문구).
    // TODO: 아래 문구는 전부 임의 작성본 — 추후 기획 정책(에러 문구 가이드) 확정 시 일괄 교체할 것.
    public var userMessage: String {
        switch self {
        case .cancelled:            return ""   // 표시 안 함
        case .network:              return "네트워크 연결을 확인해 주세요."
        case .unauthorized:         return "인증에 실패했어요. 다시 시도해 주세요."
        case .server(let message):  return message.isEmpty ? "로그인에 실패했어요." : message
        case .social(let reason):   return reason.isEmpty ? "소셜 로그인에 실패했어요." : reason
        case .unknown:              return "알 수 없는 오류가 발생했어요."
        }
    }
}
