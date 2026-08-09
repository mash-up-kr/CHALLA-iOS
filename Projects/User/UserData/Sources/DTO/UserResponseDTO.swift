import Foundation

/// `GET · PUT /api/v1/users/me` 응답 페이로드 (`BaseResponseDTO.data`).
struct UserProfileResponseDTO: Decodable, Sendable {

    let user: Payload

    struct Payload: Decodable, Sendable {
        let id: Int64
        let nickname: String?
        let profileImageUrl: String?
    }
}

struct EmptyResponseDTO: Decodable, Sendable {}
