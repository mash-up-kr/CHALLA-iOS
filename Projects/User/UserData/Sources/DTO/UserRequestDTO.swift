import Foundation

/// `PUT /api/v1/users/me` 요청 본문.
struct UpdateProfileRequestDTO: Encodable, Sendable {

    let user: Profile

    init(nickname: String, profileImageUrl: String?) {
        user = Profile(nickname: nickname, profileImageUrl: profileImageUrl)
    }

    struct Profile: Encodable, Sendable {

        let nickname: String
        let profileImageUrl: String?

        enum CodingKeys: String, CodingKey {
            case nickname
            case profileImageUrl
        }

        /// 서버 계약상 profileImageUrl은 required(nullable)라 키를 생략하면 안 된다 — 합성 인코딩은 nil일 때 키를 빼버린다.
        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(nickname, forKey: .nickname)
            try container.encode(profileImageUrl, forKey: .profileImageUrl)
        }
    }
}
