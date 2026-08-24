import Foundation

/// `POST /api/v1/rooms` 요청 본문. 서버 계약대로 `room` 한 겹을 감싼다.
struct CreateRoomRequestDTO: Encodable, Sendable {

    let room: Payload

    init(title: String, totalPhotoCount: Int) {
        room = Payload(title: title, totalPhotoCount: totalPhotoCount)
    }

    struct Payload: Encodable, Sendable {
        let title: String
        let totalPhotoCount: Int
    }
}

/// `PUT /api/v1/rooms/{id}/title` 요청 본문. 서버 계약대로 `room` 한 겹을 감싼다.
struct UpdateTitleRequestDTO: Encodable, Sendable {

    let room: Payload

    init(title: String) {
        room = Payload(title: title)
    }

    struct Payload: Encodable, Sendable {
        let title: String
    }
}

/// `POST /api/v1/rooms/join` 요청 본문.
struct JoinRoomRequestDTO: Encodable, Sendable {

    let room: Payload

    init(invitationCode: String) {
        room = Payload(invitationCode: invitationCode)
    }

    struct Payload: Encodable, Sendable {
        let invitationCode: String
    }
}
