import AuthDomain
import Foundation
import os

/// 키체인을 거치지 않는 인메모리 토큰 저장소 (갱신 경로 검증용).
final class MockTokenStore: TokenStore {

    private struct State {
        var savedTokens: [AuthToken] = []
        var clearCallCount = 0
    }

    private let state: OSAllocatedUnfairLock<State>

    init(initialTokens: [AuthToken] = []) {
        state = OSAllocatedUnfairLock(initialState: State(savedTokens: initialTokens))
    }

    var clearCallCount: Int {
        state.withLock { $0.clearCallCount }
    }

    func save(_ token: AuthToken) throws {
        state.withLock { $0.savedTokens.append(token) }
    }

    func loadAccessToken() -> String? {
        state.withLock { $0.savedTokens.last?.accessToken }
    }

    func loadRefreshToken() -> String? {
        state.withLock { $0.savedTokens.last?.refreshToken }
    }

    func clear() throws {
        state.withLock {
            $0.savedTokens.removeAll()
            $0.clearCallCount += 1
        }
    }
}
