import Foundation

/// 토큰 저장소 추상. 구현은 `AuthData`가 맡는다 (Keychain 기반).
public protocol TokenStore: Sendable {

    /// 기존 값을 덮어쓴다.
    func save(_ token: AuthToken) throws

    /// 비로그인 상태면 `nil`.
    func loadAccessToken() -> String?

    /// 비로그인 상태면 `nil`.
    func loadRefreshToken() -> String?

    func clear() throws
}
