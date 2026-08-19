import Foundation

/// `POST /api/v1/photos` 요청 본문 — 스토리지에 올라간 사진을 방에 반영해 달라는 완료 통보.
struct CompletePhotoRequestDTO: Encodable, Sendable {

    let photo: Payload

    init(roomID: Int64, cameraFilterName: String, imageURL: String) {
        photo = Payload(roomId: roomID, cameraFilterName: cameraFilterName, imageUrl: imageURL)
    }

    struct Payload: Encodable, Sendable {
        let roomId: Int64
        let cameraFilterName: String
        let imageUrl: String
    }
}

/// `POST /api/v1/photos` 응답 페이로드. 업로드 후 그 방의 남은 장수를 돌려준다.
struct CompletePhotoResponseDTO: Decodable, Sendable {

    let photo: Payload

    struct Payload: Decodable, Sendable {
        let remainedPhotoCount: Int
    }
}
