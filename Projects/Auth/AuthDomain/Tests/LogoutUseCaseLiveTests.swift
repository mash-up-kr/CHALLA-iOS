import Testing
import AuthDomain

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

    @Test("서버 로그아웃 실패는 그대로 전파되고 로컬 토큰은 남는다 (구현 정책: clear 미도달)")
    func serverFailurePropagatesAndKeepsLocalToken() async {
        let repository = MockAuthRepository(
            logoutResult: .failure(.server(message: "유효하지 않은 토큰이에요."))
        )
        let tokenStore = MockTokenStore(initialTokens: [Self.storedToken])
        let useCase = LogoutUseCase.live(repository: repository, tokenStore: tokenStore)

        await #expect(throws: AuthError.server(message: "유효하지 않은 토큰이에요.")) {
            try await useCase.run()
        }
        #expect(tokenStore.clearCallCount == 0)
        #expect(tokenStore.loadRefreshToken() == "refresh") // 재시도 가능하도록 토큰 유지
    }

    @Test("로컬 정리(clear) 실패는 .unknown으로 정규화된다")
    func clearFailureBecomesUnknown() async {
        let repository = MockAuthRepository()
        let tokenStore = MockTokenStore(initialTokens: [Self.storedToken], shouldFailOnClear: true)
        let useCase = LogoutUseCase.live(repository: repository, tokenStore: tokenStore)

        await #expect(throws: AuthError.unknown) {
            try await useCase.run()
        }
        #expect(repository.logoutRequestedTokens == ["refresh"])   // 서버 로그아웃은 이미 수행됨
    }
}
