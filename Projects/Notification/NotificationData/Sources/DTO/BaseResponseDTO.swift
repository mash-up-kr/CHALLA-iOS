import Foundation
import NotificationDomain

/// 서버 공통 응답 DTO `{ success, message, data }`.
///
/// `AuthData`·`UserData`에도 같은 타입이 있다. **이게 세 번째 복사본이다.**
/// 다른 점은 `unwrap`이 던지는 오류 타입뿐이라 공용 모듈로 뺄 수 있다 — 별도 이슈로 건다.
struct BaseResponseDTO<Payload: Decodable & Sendable>: Decodable, Sendable {

    let success: Bool
    let message: String
    /// 토큰 등록·해제 응답에는 이 키가 아예 없다 — 옵셔널이라 없어도 디코딩된다.
    let data: Payload?

    func unwrap() throws -> Payload {
        guard success, let data else {
            throw NotificationError.server(message: message)
        }
        return data
    }

    /// 페이로드를 쓰지 않는 응답에서 성공 여부만 검사한다.
    func ensureSuccess() throws {
        guard success else {
            throw NotificationError.server(message: message)
        }
    }
}
