import Foundation

/// 대기와 타이머를 경쟁시킨다. 타이머가 이기면 `STOMPError.connectTimeout`을 던진다.
///
/// 호출자가 취소되면 두 자식 모두 취소되고, `AsyncStream` 기반 대기는 취소에서 스스로 빠져나온다.
/// `sleep`을 인자로 받는 이유는 테스트가 기다리지 않게 하기 위해서다.
func withSTOMPTimeout(
    _ duration: Duration,
    sleep: @escaping @Sendable (Duration) async throws -> Void,
    _ operation: @escaping @Sendable () async -> Void
) async throws {
    try await withThrowingTaskGroup(of: Bool.self) { group in
        group.addTask {
            await operation()
            return true
        }
        group.addTask {
            // 취소된 타이머는 승부에서 빠진다 (호출자가 취소된 경우).
            do { try await sleep(duration) } catch { return true }
            return false
        }
        defer { group.cancelAll() }
        guard let finishedInTime = try await group.next(), finishedInTime else {
            throw STOMPError.connectTimeout
        }
    }
}
