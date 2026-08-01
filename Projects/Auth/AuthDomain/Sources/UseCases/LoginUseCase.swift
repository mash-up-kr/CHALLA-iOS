import Dependencies
import DependenciesMacros

/// 소셜 인증 → 서버 로그인 → 토큰 저장까지 한 번에 수행하고 결과만 돌려준다.
@DependencyClient
public struct LoginUseCase: Sendable {
    public var run: @Sendable (_ provider: AuthProvider) async throws -> LoginResult
}

extension LoginUseCase: TestDependencyKey {

    public static func live(
        social: any SocialLoginService,
        repository: any AuthRepository,
        tokenStore: any TokenStore
    ) -> LoginUseCase {
        LoginUseCase(run: { provider in
            let credential = try await social.authenticate(provider)
            let session = try await repository.login(credential)
            do {
                try tokenStore.save(session.token)
            } catch {
                throw AuthError.unknown
            }
            return LoginResult(isNewUser: session.isNewUser)
        })
    }

    public static let testValue = LoginUseCase()

    public static let previewValue = LoginUseCase(
        run: { _ in LoginResult(isNewUser: true) }
    )
}

public extension DependencyValues {
    var loginUseCase: LoginUseCase {
        get { self[LoginUseCase.self] }
        set { self[LoginUseCase.self] = newValue }
    }
}
