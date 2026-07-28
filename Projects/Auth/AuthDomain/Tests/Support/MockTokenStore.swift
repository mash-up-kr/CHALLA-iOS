import AuthDomain
import Foundation
import os

/// `save`/`clear` 호출을 캡처하는 `TokenStore` 목.
///
/// `TokenStore: Sendable`을 `@unchecked` 없이 만족시키기 위해 가변 상태를 락으로 감싼다 —
/// 배포 타깃이 iOS 17이라 `Mutex`(iOS 18+) 대신 OS 제공 `OSAllocatedUnfairLock`을 쓴다.
final class MockTokenStore: TokenStore {

    /// save 실패 주입용 오류 (실환경의 `KeychainError` 역할).
    struct SaveFailure: Error {}

    /// clear 실패 주입용 오류 (실환경의 `KeychainError` 역할).
    struct ClearFailure: Error {}

    private struct State {
        var savedTokens: [AuthToken] = []
        var clearCallCount = 0
    }

    private let state: OSAllocatedUnfairLock<State>
    private let shouldFailOnSave: Bool
    private let shouldFailOnClear: Bool

    /// - Parameter initialTokens: 로그인된 상태를 흉내 낼 초기 토큰 (save를 거치지 않고 시드).
    init(
        initialTokens: [AuthToken] = [],
        shouldFailOnSave: Bool = false,
        shouldFailOnClear: Bool = false
    ) {
        self.state = OSAllocatedUnfairLock(initialState: State(savedTokens: initialTokens))
        self.shouldFailOnSave = shouldFailOnSave
        self.shouldFailOnClear = shouldFailOnClear
    }

    // MARK: - 검증용 프로퍼티

    /// 저장돼 있는 토큰 (시드 → save 순서대로).
    var savedTokens: [AuthToken] {
        state.withLock { $0.savedTokens }
    }

    var clearCallCount: Int {
        state.withLock { $0.clearCallCount }
    }

    // MARK: - TokenStore

    func save(_ token: AuthToken) throws {
        guard !shouldFailOnSave else { throw SaveFailure() }
        state.withLock { $0.savedTokens.append(token) }
    }

    func loadAccessToken() -> String? {
        state.withLock { $0.savedTokens.last?.accessToken }
    }

    func loadRefreshToken() -> String? {
        state.withLock { $0.savedTokens.last?.refreshToken }
    }

    func clear() throws {
        guard !shouldFailOnClear else { throw ClearFailure() }
        state.withLock {
            $0.savedTokens.removeAll()
            $0.clearCallCount += 1
        }
    }
}
