import Foundation
import AuthDomain
import CHALLANetwork

/// `NetworkError` → `AuthError` 매핑.
/// 소셜 SDK 오류 매핑은 각 서비스(`KakaoLoginService`/`AppleLoginService`)가 담당한다.
extension AuthError {

    init(networkError: NetworkError) {
        switch networkError {
        case .transport:
            self = .network
        case .unacceptableStatusCode(let statusCode, _):
            // TODO: 임의 작성 문구 — 추후 기획 정책 확정 시 교체할 것 (HTTP 코드 노출 여부 포함).
            self = statusCode == 401
                ? .unauthorized
                : .server(message: "요청이 실패했어요. (HTTP \(statusCode))")
        case .invalidRequest, .nonHTTPResponse, .decoding:
            self = .unknown
        }
    }
}
