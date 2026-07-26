import Foundation
import os
import AuthDomain

/// 호출을 캡처하고 지정한 결과를 돌려주는 `AuthRepository` 목.
///
/// `AuthRepository` 규약대로 실패는 항상 `AuthError`로 던진다.
/// `AuthRepository: Sendable`을 `@unchecked` 없이 만족시키기 위해 가변 상태를
/// 락으로 감싼다 (`MockTokenStore`와 같은 방식 — iOS 17 타깃이라 `OSAllocatedUnfairLock`).
final class MockAuthRepository: AuthRepository {

    private struct State {
        var loginCredentials: [SocialCredential] = []
        var refreshRequestedTokens: [String] = []
        var logoutRequestedTokens: [String] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let loginResult: Result<AuthSession, AuthError>
    private let refreshResult: Result<AuthToken, AuthError>
    private let logoutResult: Result<Void, AuthError>

    init(
        loginResult: Result<AuthSession, AuthError> = .failure(.unknown),
        refreshResult: Result<AuthToken, AuthError> = .failure(.unknown),
        logoutResult: Result<Void, AuthError> = .success(())
    ) {
        self.loginResult = loginResult
        self.refreshResult = refreshResult
        self.logoutResult = logoutResult
    }

    // MARK: - 검증용 프로퍼티

    /// login에 전달된 자격증명 (호출 순서대로).
    var loginCredentials: [SocialCredential] { state.withLock { $0.loginCredentials } }

    /// refresh에 전달된 refreshToken (호출 순서대로).
    var refreshRequestedTokens: [String] { state.withLock { $0.refreshRequestedTokens } }

    /// logout에 전달된 refreshToken (호출 순서대로).
    var logoutRequestedTokens: [String] { state.withLock { $0.logoutRequestedTokens } }

    // MARK: - AuthRepository

    func login(_ credential: SocialCredential) async throws -> AuthSession {
        state.withLock { $0.loginCredentials.append(credential) }
        return try loginResult.get()
    }

    func refresh(refreshToken: String) async throws -> AuthToken {
        state.withLock { $0.refreshRequestedTokens.append(refreshToken) }
        return try refreshResult.get()
    }

    func logout(refreshToken: String) async throws {
        state.withLock { $0.logoutRequestedTokens.append(refreshToken) }
        try logoutResult.get()
    }
}
