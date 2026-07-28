import AuthDomain
import Testing

@Suite("LoginUseCase.live")
struct LoginUseCaseLiveTests {

    private static let credential = SocialCredential(
        provider: .kakao,
        idToken: "id-token",
        authorizationCode: nil
    )

    private static let session = AuthSession(
        token: AuthToken(accessToken: "access", refreshToken: "refresh"),
        isNewUser: false
    )

    @Test("성공 흐름: 소셜 → 서버 → 토큰 저장 → LoginResult 반환")
    func successSavesTokenAndReturnsResult() async throws {
        let social = MockSocialLoginService(result: .success(Self.credential))
        let repository = MockAuthRepository(loginResult: .success(Self.session))
        let tokenStore = MockTokenStore()
        let useCase = LoginUseCase.live(social: social, repository: repository, tokenStore: tokenStore)

        let result = try await useCase.run(.kakao)

        #expect(result == LoginResult(isNewUser: false))
        #expect(tokenStore.savedTokens == [AuthToken(accessToken: "access", refreshToken: "refresh")])
        // 요청받은 provider가 소셜 인증까지 그대로 전달되고, 그 자격증명이 서버 로그인으로 넘어가는지.
        #expect(social.authenticatedProviders == [.kakao])
        #expect(repository.loginCredentials == [Self.credential])
    }

    @Test("소셜 취소는 .cancelled 그대로 전파되고 저장은 일어나지 않는다")
    func socialCancelPropagates() async {
        let tokenStore = MockTokenStore()
        let useCase = LoginUseCase.live(
            social: MockSocialLoginService(result: .failure(.cancelled)),
            repository: MockAuthRepository(loginResult: .success(Self.session)),
            tokenStore: tokenStore
        )

        await #expect(throws: AuthError.cancelled) {
            _ = try await useCase.run(.kakao)
        }
        #expect(tokenStore.savedTokens.isEmpty)
    }

    @Test("토큰 저장 실패는 .unknown으로 정규화된다")
    func saveFailureBecomesUnknown() async {
        let useCase = LoginUseCase.live(
            social: MockSocialLoginService(result: .success(Self.credential)),
            repository: MockAuthRepository(loginResult: .success(Self.session)),
            tokenStore: MockTokenStore(shouldFailOnSave: true)
        )

        await #expect(throws: AuthError.unknown) {
            _ = try await useCase.run(.kakao)
        }
    }
}
