import Foundation
import Keychain
import os

/// 인메모리 딕셔너리로 동작하는 `Keychain` 목. 실제 SecItem을 건드리지 않아 순수 유닛테스트가 된다.
///
/// `Keychain: Sendable`을 `@unchecked` 없이 만족시키기 위해 저장소를 락으로 감싼다
/// (iOS 17 타깃이라 `OSAllocatedUnfairLock`).
final class MockKeychain: Keychain {

    /// save/load 실패 주입용 오류 (실환경의 `KeychainError.unexpectedStatus` 역할).
    struct InjectedFailure: Error {}

    private struct State {
        var storage: [String: Data] = [:]
        var failOnSave: Bool
        var failOnLoad: Bool
        var failOnDelete: Bool
    }

    private let state: OSAllocatedUnfairLock<State>

    init(
        shouldFailOnSave: Bool = false,
        shouldFailOnLoad: Bool = false,
        shouldFailOnDelete: Bool = false
    ) {
        state = OSAllocatedUnfairLock(
            initialState: State(
                failOnSave: shouldFailOnSave,
                failOnLoad: shouldFailOnLoad,
                failOnDelete: shouldFailOnDelete
            )
        )
    }

    // MARK: - Failure Injection

    /// 이미 값이 든 상태에서 실패로 전환하기 위한 스위치.
    func setFailOnSave(_ shouldFail: Bool) {
        state.withLock { $0.failOnSave = shouldFail }
    }

    /// 특정 키에 저장된 원본 바이트. 저장 키·포맷을 직접 검증할 때 쓴다.
    func storedData(for key: String) -> Data? {
        state.withLock { $0.storage[key] }
    }

    /// 현재 보관 중인 항목 수. 부분 저장으로 항목이 늘어나지 않는지 확인할 때 쓴다.
    var itemCount: Int {
        state.withLock { $0.storage.count }
    }

    // MARK: - Keychain

    func save(_ data: Data, for key: String) throws {
        try state.withLock {
            guard !$0.failOnSave else { throw InjectedFailure() }
            $0.storage[key] = data
        }
    }

    func load(for key: String) throws -> Data? {
        try state.withLock {
            guard !$0.failOnLoad else { throw InjectedFailure() }
            return $0.storage[key]
        }
    }

    func delete(for key: String) throws {
        try state.withLock {
            guard !$0.failOnDelete else { throw InjectedFailure() }
            $0.storage[key] = nil
        }
    }
}
