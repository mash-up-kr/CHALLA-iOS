import Foundation

/// `POST /api/v1/auth/login` 응답 페이로드 (`BaseResponseDTO.data`).
struct LoginResponseDTO: Decodable, Sendable {

    let auth: Payload

    struct Payload: Decodable, Sendable {
        let accessToken: String
        let refreshToken: String
        let isNew: Bool
    }
}

/// `POST /api/v1/auth/refresh` 응답 페이로드.
struct TokenPairResponseDTO: Decodable, Sendable {

    let auth: Payload

    struct Payload: Decodable, Sendable {
        let accessToken: String
        let refreshToken: String
    }
}
