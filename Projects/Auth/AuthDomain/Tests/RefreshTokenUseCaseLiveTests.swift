import AuthDomain
import Testing

@Suite("RefreshTokenUseCase.live")
struct RefreshTokenUseCaseLiveTests {

    private static let oldToken = AuthToken(accessToken: "old-access", refreshToken: "old-refresh")
    private static let newToken = AuthToken(accessToken: "new-access", refreshToken: "new-refresh")

    @Test("저장 토큰이 없으면 서버 호출 없이 .unauthorized를 던진다 (재로그인 필요)")
    func withoutStoredTokenThrowsUnauthorized() async {
        let repository = MockAuthRepository()
        let useCase = RefreshTokenUseCase.live(
            repository: repository,
            tokenStore: MockTokenStore()
        )

        await #expect(throws: AuthError.unauthorized) {
            _ = try await useCase.run()
        }
        #expect(repository.refreshRequestedTokens.isEmpty)
    }

    @Test("성공: 저장된 refreshToken으로 갱신하고 새 토큰을 저장·반환한다")
    func successSavesAndReturnsNewToken() async throws {
        let repository = MockAuthRepository(refreshResult: .success(Self.newToken))
        let tokenStore = MockTokenStore(initialTokens: [Self.oldToken])
        let useCase = RefreshTokenUseCase.live(repository: repository, tokenStore: tokenStore)

        let token = try await useCase.run()

        #expect(token == Self.newToken)
        #expect(repository.refreshRequestedTokens == ["old-refresh"]) // 저장돼 있던 토큰으로 요청
        #expect(tokenStore.savedTokens.last == Self.newToken) // 새 토큰 재저장
    }

    @Test("서버 갱신 실패는 그대로 전파되고 저장은 일어나지 않는다")
    func refreshFailurePropagatesWithoutSave() async {
        let repository = MockAuthRepository(refreshResult: .failure(.unauthorized))
        let tokenStore = MockTokenStore(initialTokens: [Self.oldToken])
        let useCase = RefreshTokenUseCase.live(repository: repository, tokenStore: tokenStore)

        await #expect(throws: AuthError.unauthorized) {
            _ = try await useCase.run()
        }
        #expect(tokenStore.savedTokens == [Self.oldToken]) // 기존 토큰 그대로 (새 저장 없음)
    }

    @Test("새 토큰 저장 실패는 .unknown으로 정규화된다")
    func saveFailureBecomesUnknown() async {
        let repository = MockAuthRepository(refreshResult: .success(Self.newToken))
        let tokenStore = MockTokenStore(initialTokens: [Self.oldToken], shouldFailOnSave: true)
        let useCase = RefreshTokenUseCase.live(repository: repository, tokenStore: tokenStore)

        await #expect(throws: AuthError.unknown) {
            _ = try await useCase.run()
        }
    }
}
