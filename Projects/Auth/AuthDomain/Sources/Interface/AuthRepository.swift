import Foundation

/// 인증 서버 API 추상. 구현은 `AuthData`가 맡는다.
///
/// 구현체는 실패를 `AuthError`로 정규화해 던져야 한다.
public protocol AuthRepository: Sendable {

    func login(_ credential: SocialCredential) async throws -> AuthSession

    func refresh(refreshToken: String) async throws -> AuthToken

    /// 서버에서 refreshToken을 무효화한다.
    func logout(refreshToken: String) async throws
}
