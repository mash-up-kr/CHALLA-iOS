import AuthDomain
import Testing

@Suite("RestoreSessionUseCase.live")
struct RestoreSessionUseCaseLiveTests {

    private static let storedToken = AuthToken(accessToken: "access", refreshToken: "refresh")

    private func useCase(
        tokenStore: MockTokenStore,
        hasLaunchedBefore: Bool
    ) -> (RestoreSessionUseCase, MockLaunchStateStore) {
        let launchState = MockLaunchStateStore(hasLaunchedBefore: hasLaunchedBefore)
        return (.live(tokenStore: tokenStore, launchState: launchState), launchState)
    }

    @Test("저장된 토큰이 있으면 .restored — 자동 로그인으로 이어진다")
    func restoresWithStoredToken() {
        let tokenStore = MockTokenStore(initialTokens: [Self.storedToken])
        let (useCase, _) = useCase(tokenStore: tokenStore, hasLaunchedBefore: true)

        #expect(useCase.run() == .restored)
        #expect(tokenStore.clearCallCount == 0)
    }

    @Test("저장된 토큰이 없으면 .signedOut — 실패할 요청을 보내지 않는다")
    func signedOutWithoutStoredToken() {
        let (useCase, _) = useCase(tokenStore: MockTokenStore(), hasLaunchedBefore: true)

        #expect(useCase.run() == .signedOut)
    }

    @Test("설치 후 최초 실행이면 남아 있던 키체인을 지우고 .signedOut을 돌려준다")
    func firstLaunchClearsKeychain() {
        let tokenStore = MockTokenStore(initialTokens: [Self.storedToken]) // 이전 설치의 잔여물
        let (useCase, launchState) = useCase(tokenStore: tokenStore, hasLaunchedBefore: false)

        #expect(useCase.run() == .signedOut)
        #expect(tokenStore.clearCallCount == 1)
        #expect(tokenStore.loadRefreshToken() == nil)
        #expect(launchState.hasLaunchedBefore) // 다음 실행에서는 초기화하지 않는다
    }

    @Test("최초 실행 초기화는 한 번만 — 두 번째 호출은 저장된 토큰을 그대로 살린다")
    func clearsOnlyOnce() throws {
        let tokenStore = MockTokenStore(initialTokens: [Self.storedToken])
        let (useCase, _) = useCase(tokenStore: tokenStore, hasLaunchedBefore: false)

        #expect(useCase.run() == .signedOut)

        try tokenStore.save(Self.storedToken) // 초기화 뒤 로그인한 상황
        #expect(useCase.run() == .restored)
        #expect(tokenStore.clearCallCount == 1)
    }

    @Test("최초 실행 키체인 삭제가 실패해도 로그인 화면으로 진행한다 (앱이 멈추지 않는다)")
    func firstLaunchSurvivesClearFailure() {
        let tokenStore = MockTokenStore(initialTokens: [Self.storedToken], shouldFailOnClear: true)
        let (useCase, launchState) = useCase(tokenStore: tokenStore, hasLaunchedBefore: false)

        #expect(useCase.run() == .signedOut)
        #expect(launchState.hasLaunchedBefore)
    }
}
