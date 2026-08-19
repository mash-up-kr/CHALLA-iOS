import Foundation

/// `POST`·`DELETE /api/v1/notifications/tokens` 요청 본문.
///
/// 두 API가 같은 모양이라 한 타입으로 쓴다. 서버가 `notification` 키로 한 번 감싼다.
struct DeviceTokenRequestDTO: Encodable, Sendable {

    let notification: Payload

    init(token: String) {
        notification = Payload(token: token)
    }

    struct Payload: Encodable, Sendable {
        /// FCM registration token.
        let token: String
    }
}

/// `POST /api/v1/notifications/test` 요청 본문.
struct TestPushRequestDTO: Encodable, Sendable {

    let notification: Payload

    init(title: String, body: String) {
        notification = Payload(title: title, body: body)
    }

    struct Payload: Encodable, Sendable {
        let title: String
        let body: String
    }
}
