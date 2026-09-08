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

struct UpdateCoverRequestDTO: Encodable, Sendable {

    let room: Payload

    init(coverImageUrl: String?, coverStickerId: Int64?, coverStickerColorId: Int64?) {
        room = Payload(
            coverImageUrl: coverImageUrl,
            coverStickerId: coverStickerId,
            coverStickerColorId: coverStickerColorId
        )
    }

    struct Payload: Encodable, Sendable {
        let coverImageUrl: String?
        let coverStickerId: Int64?
        let coverStickerColorId: Int64?

        private enum CodingKeys: String, CodingKey {
            case coverImageUrl
            case coverStickerId
            case coverStickerColorId
        }

        /// 전체 교체 계약이라 없애는 값도 null로 실어야 한다 — 합성 encode는 nil 키를 빼 버린다
        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(coverImageUrl, forKey: .coverImageUrl)
            try container.encode(coverStickerId, forKey: .coverStickerId)
            try container.encode(coverStickerColorId, forKey: .coverStickerColorId)
        }
    }
}
