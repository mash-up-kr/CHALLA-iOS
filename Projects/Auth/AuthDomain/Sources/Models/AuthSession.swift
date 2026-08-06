import Foundation

/// 로그인에 성공한 사용자의 인증 세션.
///
/// 토큰이 들어 있어 저장 전 단계까지만 다룬다 —
/// Feature에는 토큰을 감춘 `LoginResult`만 노출한다.
public struct AuthSession: Sendable, Equatable {

    public let token: AuthToken
    public let isNewUser: Bool

    public init(token: AuthToken, isNewUser: Bool) {
        self.token = token
        self.isNewUser = isNewUser
    }
}
