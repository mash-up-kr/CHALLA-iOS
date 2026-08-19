import Foundation

/// `POST /api/v1/uploads` 요청 본문. `UserData`의 같은 타입을 복사한 것 (#51 머지 후 통합).
struct IssueUploadURLRequestDTO: Encodable, Sendable {

    let upload: Payload

    init(purpose: String, contentType: String) {
        upload = Payload(purpose: purpose, contentType: contentType)
    }

    struct Payload: Encodable, Sendable {
        let purpose: String // "PROFILE_IMAGE" | "PHOTO"
        let contentType: String
    }
}

/// `POST /api/v1/uploads` 응답 페이로드. `expiresInSeconds`도 오지만 발급 직후 올리므로 쓰지 않는다.
struct UploadURLResponseDTO: Decodable, Sendable {

    let upload: Payload

    struct Payload: Decodable, Sendable {
        let uploadUrl: String
        let imageUrl: String
    }
}
