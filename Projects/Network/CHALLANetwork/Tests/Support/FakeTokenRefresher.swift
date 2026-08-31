import CHALLANetwork
import Foundation
import os

/// 갱신 호출 횟수와 넘겨받은 만료 토큰을 기록하는 스텁.
final class FakeTokenRefresher: TokenRefreshing {

    private struct State {
        var receivedStaleTokens: [String?] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let result: Bool

    init(result: Bool) {
        self.result = result
    }

    var callCount: Int {
        state.withLock { $0.receivedStaleTokens.count }
    }

    var receivedStaleTokens: [String?] {
        state.withLock { $0.receivedStaleTokens }
    }

    func refreshToken(replacing staleAccessToken: String?) async -> Bool {
        state.withLock { $0.receivedStaleTokens.append(staleAccessToken) }
        return result
    }
}
