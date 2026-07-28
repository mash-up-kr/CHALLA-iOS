import AuthDomain
import Foundation

/// 서버 공통 응답 DTO `{ success, message, data }`.
///
/// 다른 Data 모듈(Room/User…)도 같은 DTO를 쓰게 되면 공용 모듈(Shared/DTOKit 등)로 승격한다 — 그전까지 복붙 금지.
struct BaseResponseDTO<Payload: Decodable & Sendable>: Decodable, Sendable {

    let success: Bool
    let message: String
    let data: Payload?

    /// `success && data 존재` → payload, 아니면 `AuthError.server(message:)` throw.
    func unwrap() throws -> Payload {
        guard success, let data else {
            throw AuthError.server(message: message)
        }
        return data
    }

    /// 페이로드를 쓰지 않는 응답(logout 등)에서 성공 여부만 검사한다.
    /// `data`가 `null`이어도 `success`면 통과 — 실패면 `AuthError.server(message:)` throw.
    func ensureSuccess() throws {
        guard success else {
            throw AuthError.server(message: message)
        }
    }
}
