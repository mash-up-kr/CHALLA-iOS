import Foundation

/// UserData의 UploadDTO와 중복 — 공통화는 #51 소관
struct IssueUploadURLRequestDTO: Encodable, Sendable {

    let upload: Payload

    init(purpose: String, contentType: String) {
        upload = Payload(purpose: purpose, contentType: contentType)
    }

    struct Payload: Encodable, Sendable {
        let purpose: String
        let contentType: String
    }
}

struct UploadURLResponseDTO: Decodable, Sendable {

    let upload: Payload

    struct Payload: Decodable, Sendable {
        let uploadUrl: String
        let imageUrl: String
    }
}
