import AuthDomain
import CHALLANetwork
import Foundation

/// 401을 받은 요청들이 동시에 갱신을 때리지 않도록, 갱신을 한 번만 수행하고 결과를 모두에게 나눠준다.
///
/// 서버가 refreshToken을 회전(rotate)시키면 같은 토큰으로 두 번 갱신할 수 없다 —
/// 중복 갱신은 두 번째가 거절되며 살아 있는 세션을 끊어버린다.
public actor AuthTokenRefresher: TokenRefreshing {

    private let refresh: @Sendable () async throws -> AuthToken
    private let tokenStore: any TokenStore
    private let onSessionExpired: @Sendable () -> Void

    private var inFlight: Task<Bool, Never>?

    public init(
        refresh: @escaping @Sendable () async throws -> AuthToken,
        tokenStore: any TokenStore,
        onSessionExpired: @escaping @Sendable () -> Void
    ) {
        self.refresh = refresh
        self.tokenStore = tokenStore
        self.onSessionExpired = onSessionExpired
    }

    public func refreshToken(replacing staleAccessToken: String?) async -> Bool {
        if hasTokenNewer(than: staleAccessToken) {
            return true
        }

        if let inFlight {
            return await inFlight.value
        }

        let task = Task { await performRefresh() }
        inFlight = task
        let didRefresh = await task.value
        inFlight = nil
        return didRefresh
    }

    /// 다른 요청이 이미 갱신을 끝냈다면 재시도만 하면 된다.
    private func hasTokenNewer(than staleAccessToken: String?) -> Bool {
        guard let staleAccessToken, let current = tokenStore.loadAccessToken() else { return false }

        return current != staleAccessToken
    }

    private func performRefresh() async -> Bool {
        do {
            _ = try await refresh()
            return true
        } catch is CancellationError {
            return false
        } catch AuthError.network {
            return false // 일시적 장애 — 세션은 살려두고 다음 요청에서 다시 시도한다
        } catch {
            expireSession()
            return false
        }
    }

    /// 갱신이 거절됐다 = 저장된 토큰으로는 더 이상 아무 요청도 통과하지 못한다.
    private func expireSession() {
        try? tokenStore.clear()
        onSessionExpired()
    }
}
