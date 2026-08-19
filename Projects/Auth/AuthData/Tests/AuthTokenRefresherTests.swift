import AuthData
import AuthDomain
import Foundation
import os
import Testing

@Suite("AuthTokenRefresher")
struct AuthTokenRefresherTests {

    private static let newToken = AuthToken(accessToken: "new-access", refreshToken: "new-refresh")
    private static let oldToken = AuthToken(accessToken: "old-access", refreshToken: "old-refresh")

    private final class ExpirationSpy: Sendable {
        private let count = OSAllocatedUnfairLock(initialState: 0)

        var callCount: Int {
            count.withLock { $0 }
        }

        func notify() {
            count.withLock { $0 += 1 }
        }
    }

    /// 갱신 호출 횟수를 세고, `blocking`이면 `release()`까지 갱신을 붙잡아 둔다.
    private final class RefreshSpy: Sendable {
        private let count = OSAllocatedUnfairLock(initialState: 0)
        private let gate: AsyncStream<Void>?
        private let opener: AsyncStream<Void>.Continuation?
        private let token: AuthToken

        init(returning token: AuthToken, blocking: Bool = false) {
            self.token = token
            if blocking {
                let stream = AsyncStream.makeStream(of: Void.self)
                gate = stream.stream
                opener = stream.continuation
            } else {
                gate = nil
                opener = nil
            }
        }

        var callCount: Int {
            count.withLock { $0 }
        }

        func release() {
            opener?.finish()
        }

        func run() async throws -> AuthToken {
            count.withLock { $0 += 1 }
            if let gate {
                for await _ in gate {}
            }
            return token
        }
    }

    @Test("갱신에 성공하면 true를 돌려준다 (재시도 가능)")
    func successReturnsTrue() async {
        let tokenStore = MockTokenStore(initialTokens: [Self.oldToken])
        let spy = RefreshSpy(returning: Self.newToken)
        let refresher = AuthTokenRefresher(
            refresh: { try await spy.run() },
            tokenStore: tokenStore,
            onSessionExpired: {}
        )

        #expect(await refresher.refreshToken(replacing: "old-access"))
        #expect(spy.callCount == 1)
    }

    @Test("네트워크 오류면 false지만 세션은 유지한다 (오프라인에 로그아웃되지 않는다)")
    func networkFailureKeepsSession() async {
        let tokenStore = MockTokenStore(initialTokens: [Self.oldToken])
        let expiration = ExpirationSpy()
        let refresher = AuthTokenRefresher(
            refresh: { throw AuthError.network },
            tokenStore: tokenStore,
            onSessionExpired: { expiration.notify() }
        )

        #expect(await refresher.refreshToken(replacing: "old-access") == false)
        #expect(tokenStore.clearCallCount == 0)
        #expect(expiration.callCount == 0)
    }

    @Test(
        "갱신이 거절되면 키체인을 지우고 세션 만료를 알린다",
        arguments: [AuthError.unauthorized, .server(message: "만료된 토큰"), .unknown]
    )
    func rejectionClearsKeychainAndNotifies(error: AuthError) async {
        let tokenStore = MockTokenStore(initialTokens: [Self.oldToken])
        let expiration = ExpirationSpy()
        let refresher = AuthTokenRefresher(
            refresh: { throw error },
            tokenStore: tokenStore,
            onSessionExpired: { expiration.notify() }
        )

        #expect(await refresher.refreshToken(replacing: "old-access") == false)
        #expect(tokenStore.clearCallCount == 1)
        #expect(tokenStore.loadRefreshToken() == nil)
        #expect(expiration.callCount == 1)
    }

    @Test("취소는 세션 만료로 보지 않는다")
    func cancellationDoesNotExpireSession() async {
        let tokenStore = MockTokenStore(initialTokens: [Self.oldToken])
        let expiration = ExpirationSpy()
        let refresher = AuthTokenRefresher(
            refresh: { throw CancellationError() },
            tokenStore: tokenStore,
            onSessionExpired: { expiration.notify() }
        )

        #expect(await refresher.refreshToken(replacing: "old-access") == false)
        #expect(tokenStore.clearCallCount == 0)
        #expect(expiration.callCount == 0)
    }

    @Test("동시에 401을 받은 요청들이 갱신을 한 번만 호출한다 (refreshToken 회전 대비)")
    func concurrentCallsRefreshOnce() async throws {
        let tokenStore = MockTokenStore(initialTokens: [Self.oldToken])
        let spy = RefreshSpy(returning: Self.newToken, blocking: true)
        let refresher = AuthTokenRefresher(
            refresh: { try await spy.run() },
            tokenStore: tokenStore,
            onSessionExpired: {}
        )

        let waiting = Task {
            await withTaskGroup(of: Bool.self) { group in
                for _ in 0 ..< 5 {
                    group.addTask { await refresher.refreshToken(replacing: "old-access") }
                }
                return await group.reduce(into: [Bool]()) { $0.append($1) }
            }
        }

        try await Task.sleep(for: .milliseconds(100)) // 다섯 호출이 진행 중인 갱신에 합류할 시간
        spy.release()

        #expect(await waiting.value.allSatisfy(\.self))
        #expect(spy.callCount == 1)
    }

    @Test("이미 다른 요청이 갱신을 끝냈다면 갱신 없이 재시도만 허용한다")
    func skipsRefreshWhenTokenAlreadyRotated() async {
        let tokenStore = MockTokenStore(initialTokens: [Self.newToken])
        let spy = RefreshSpy(returning: Self.newToken)
        let refresher = AuthTokenRefresher(
            refresh: { try await spy.run() },
            tokenStore: tokenStore,
            onSessionExpired: {}
        )

        #expect(await refresher.refreshToken(replacing: "old-access"))
        #expect(spy.callCount == 0)
    }

    @Test("만료 토큰을 알 수 없으면(nil) 그대로 갱신한다")
    func refreshesWhenStaleTokenUnknown() async {
        let tokenStore = MockTokenStore(initialTokens: [Self.oldToken])
        let spy = RefreshSpy(returning: Self.newToken)
        let refresher = AuthTokenRefresher(
            refresh: { try await spy.run() },
            tokenStore: tokenStore,
            onSessionExpired: {}
        )

        #expect(await refresher.refreshToken(replacing: nil))
        #expect(spy.callCount == 1)
    }
}
