import Foundation

/// `POST /api/v1/photos` 요청 본문 — 스토리지에 올라간 사진을 방에 반영해 달라는 완료 통보.
struct CompletePhotoRequestDTO: Encodable, Sendable {

    let photo: Payload

    init(
        roomID: Int64,
        cameraFilterName: String,
        imageURL: String,
        thumbnailImageURL: String? = nil
    ) {
        photo = Payload(
            roomId: roomID,
            cameraFilterName: cameraFilterName,
            imageUrl: imageURL,
            thumbnailImageUrl: thumbnailImageURL
        )
    }

    struct Payload: Encodable, Sendable {
        let roomId: Int64
        let cameraFilterName: String
        let imageUrl: String
        /// 축소본을 못 만들었거나 올리지 못하면 nil — 서버가 그대로 비워 두고,
        /// 목록 조회 때 이 사진만 원본 주소로 폴백된다.
        let thumbnailImageUrl: String?
    }
}

/// `POST /api/v1/photos` 응답 페이로드. 업로드 후 그 방의 남은 장수를 돌려준다.
struct CompletePhotoResponseDTO: Decodable, Sendable {

    let photo: Payload

    struct Payload: Decodable, Sendable {
        let remainedPhotoCount: Int
    }
}
