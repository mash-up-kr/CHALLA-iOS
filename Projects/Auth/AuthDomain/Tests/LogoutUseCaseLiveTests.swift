import AuthDomain
import Testing

@Suite("LogoutUseCase.live")
struct LogoutUseCaseLiveTests {

    private static let storedToken = AuthToken(accessToken: "access", refreshToken: "refresh")

    @Test("저장 토큰이 없으면(이미 비로그인) 서버를 호출하지 않고 로컬 정리만 한다")
    func withoutStoredTokenSkipsServerAndClears() async throws {
        let repository = MockAuthRepository()
        let tokenStore = MockTokenStore()
        let useCase = LogoutUseCase.live(repository: repository, tokenStore: tokenStore)

        try await useCase.run()

        #expect(repository.logoutRequestedTokens.isEmpty)
        #expect(tokenStore.clearCallCount == 1)
    }

    @Test("저장 토큰이 있으면 그 refreshToken으로 서버 로그아웃 후 로컬을 정리한다")
    func withStoredTokenLogsOutServerThenClears() async throws {
        let repository = MockAuthRepository()
        let tokenStore = MockTokenStore(initialTokens: [Self.storedToken])
        let useCase = LogoutUseCase.live(repository: repository, tokenStore: tokenStore)

        try await useCase.run()

        #expect(repository.logoutRequestedTokens == ["refresh"])
        #expect(tokenStore.clearCallCount == 1)
        #expect(tokenStore.loadRefreshToken() == nil)
    }

    @Test("네트워크 오류는 전파되고 로컬 토큰은 남는다 (같은 조작을 다시 시도할 수 있어야 한다)")
    func networkFailurePropagatesAndKeepsLocalToken() async {
        let repository = MockAuthRepository(logoutResult: .failure(.network))
        let tokenStore = MockTokenStore(initialTokens: [Self.storedToken])
        let useCase = LogoutUseCase.live(repository: repository, tokenStore: tokenStore)

        await #expect(throws: AuthError.network) {
            try await useCase.run()
        }
        #expect(tokenStore.clearCallCount == 0)
        #expect(tokenStore.loadRefreshToken() == "refresh")
    }

    @Test(
        "서버가 세션을 거절하면 오류를 삼키고 로컬을 정리한다 (남기면 영구히 로그아웃할 수 없다)",
        arguments: [AuthError.server(message: "유효하지 않은 토큰이에요."), .unauthorized, .unknown]
    )
    func serverRejectionStillClearsLocalToken(error: AuthError) async throws {
        let repository = MockAuthRepository(logoutResult: .failure(error))
        let tokenStore = MockTokenStore(initialTokens: [Self.storedToken])
        let useCase = LogoutUseCase.live(repository: repository, tokenStore: tokenStore)

        try await useCase.run()

        #expect(tokenStore.clearCallCount == 1)
        #expect(tokenStore.loadRefreshToken() == nil)
    }

    @Test("로컬 정리(clear) 실패는 .unknown으로 정규화된다")
    func clearFailureBecomesUnknown() async {
        let repository = MockAuthRepository()
        let tokenStore = MockTokenStore(initialTokens: [Self.storedToken], shouldFailOnClear: true)
        let useCase = LogoutUseCase.live(repository: repository, tokenStore: tokenStore)

        await #expect(throws: AuthError.unknown) {
            try await useCase.run()
        }
        #expect(repository.logoutRequestedTokens == ["refresh"]) // 서버 로그아웃은 이미 수행됨
    }
}
