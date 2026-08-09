import AuthDomain
import Foundation

/// `POST /api/v1/auth/login` 요청 본문.
struct LoginRequestDTO: Encodable, Sendable {

    let auth: Payload

    /// 서버 enum 문자열 매핑은 여기(Data)에서만 한다 — Domain은 "KAKAO"/"APPLE"의 존재를 모른다.
    init(from credential: SocialCredential) {
        auth = Payload(
            provider: credential.provider == .kakao ? "KAKAO" : "APPLE",
            idToken: credential.idToken,
            authorizationCode: credential.authorizationCode
        )
    }

    struct Payload: Encodable, Sendable {
        let provider: String // "KAKAO" | "APPLE"
        let idToken: String
        let authorizationCode: String?
    }
}

/// `POST /api/v1/auth/refresh` 요청 본문.
struct RefreshRequestDTO: Encodable, Sendable {

    let auth: Payload

    init(refreshToken: String) {
        auth = Payload(refreshToken: refreshToken)
    }

    struct Payload: Encodable, Sendable {
        let refreshToken: String
    }
}

/// `POST /api/v1/auth/logout` 요청 본문 (헤더에는 별도로 Bearer accessToken이 붙는다).
struct LogoutRequestDTO: Encodable, Sendable {

    let auth: Payload

    init(refreshToken: String) {
        auth = Payload(refreshToken: refreshToken)
    }

    struct Payload: Encodable, Sendable {
        let refreshToken: String
    }
}
