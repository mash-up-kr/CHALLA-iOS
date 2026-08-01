import Foundation

/// 소셜 SDK 인증이 돌려준 원시 자격증명 (서버 전송 직전 값).
///
/// - Kakao: OIDC `idToken`을 담고, `authorizationCode`는 `nil`.
/// - Apple: `identityToken`을 `idToken`으로 담고, `authorizationCode`를 함께 채운다.
///
/// `SocialLoginService`가 만들어 `AuthRepository`가 받는다 — 그 사이에서만 오간다.
public struct SocialCredential: Sendable, Equatable {

    public let provider: AuthProvider
    public let idToken: String
    public let authorizationCode: String?

    public init(provider: AuthProvider, idToken: String, authorizationCode: String?) {
        self.provider = provider
        self.idToken = idToken
        self.authorizationCode = authorizationCode
    }
}
