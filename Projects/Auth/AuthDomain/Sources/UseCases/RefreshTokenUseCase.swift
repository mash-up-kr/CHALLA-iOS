import Dependencies
import DependenciesMacros

/// 저장된 refreshToken으로 토큰 쌍을 갱신한다.
@DependencyClient
public struct RefreshTokenUseCase: Sendable {
    public var run: @Sendable () async throws -> AuthToken
}

extension RefreshTokenUseCase: TestDependencyKey {

    public static func live(
        repository: any AuthRepository,
        tokenStore: any TokenStore
    ) -> RefreshTokenUseCase {
        RefreshTokenUseCase(run: {
            guard let refreshToken = tokenStore.loadRefreshToken() else {
                throw AuthError.unauthorized
            }
            let token = try await repository.refresh(refreshToken: refreshToken)
            do {
                try tokenStore.save(token)
            } catch {
                throw AuthError.unknown
            }
            return token
        })
    }

    public static let testValue = RefreshTokenUseCase()

    public static let previewValue = RefreshTokenUseCase(
        run: { AuthToken(accessToken: "a", refreshToken: "r") }
    )
}

public extension DependencyValues {
    var refreshTokenUseCase: RefreshTokenUseCase {
        get { self[RefreshTokenUseCase.self] }
        set { self[RefreshTokenUseCase.self] = newValue }
    }
}
