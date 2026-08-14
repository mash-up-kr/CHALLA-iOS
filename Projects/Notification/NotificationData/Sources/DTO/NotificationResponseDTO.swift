import Foundation

/// `POST /api/v1/notifications/test` 응답 페이로드.
struct TestPushResponseDTO: Decodable, Sendable {

    let notification: Payload

    struct Payload: Decodable, Sendable {
        /// 전송에 성공한 토큰 수. `0`이면 이 계정에 등록된 토큰이 없다는 뜻이다.
        let sentCount: Int
    }
}

/// 토큰 등록·해제처럼 돌려받을 값이 없는 응답에 쓰는 빈 타입.
/// 서버가 `data` 키를 아예 보내지 않지만 `BaseResponseDTO.data`가 옵셔널이라 디코딩된다.
struct EmptyResponseDTO: Decodable, Sendable {}
