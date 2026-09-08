import Foundation

/// 서버 공통 응답 DTO `{ success, message, data }`. 내용물(`Payload`)만 API마다 갈아끼운다.
///
/// 실패 시 어떤 도메인 오류를 던질지는 이 타입이 모른다 — 호출한 Data 모듈이 클로저로 넘긴다.
/// 각 모듈은 자기 오류를 묶은 `unwrap()` / `ensureSuccess()` 확장만 두고 기존 호출부를 그대로 쓴다.
public struct BaseResponseDTO<Payload: Decodable & Sendable>: Decodable, Sendable {

    public let success: Bool
    public let message: String
    /// 토큰 등록·해제처럼 돌려받을 값이 없는 응답에는 이 키가 없다 — 옵셔널이라 없어도 디코딩된다.
    public let data: Payload?

    /// `success && data 존재` → payload, 아니면 `makeError(message)` throw.
    public func unwrap(orServerError makeError: (String) -> any Error) throws -> Payload {
        guard success, let data else {
            throw makeError(message)
        }
        return data
    }

    /// 페이로드를 쓰지 않는 응답(logout 등)에서 성공 여부만 검사한다.
    /// `data`가 `null`이어도 `success`면 통과 — 실패면 `makeError(message)` throw.
    public func ensureSuccess(orServerError makeError: (String) -> any Error) throws {
        guard success else {
            throw makeError(message)
        }
    }
}
