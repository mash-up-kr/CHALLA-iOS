import Foundation

/// `POST /api/v1/notifications/test` 응답 페이로드.
struct TestPushResponseDTO: Decodable, Sendable {

    let notification: Payload

    struct Payload: Decodable, Sendable {
        /// 전송에 성공한 토큰 수. `0`이면 이 계정에 등록된 토큰이 없다는 뜻이다.
        let sentCount: Int
    }
}
