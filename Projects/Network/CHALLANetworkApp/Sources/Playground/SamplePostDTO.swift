import Foundation

/// JSONPlaceholder `/posts` 응답 모델. `Response.map`/`request(as:)` 디코딩 데모용.
struct SamplePostDTO: Decodable, Identifiable {
    let id: Int
    let userId: Int
    let title: String
    let body: String
}
