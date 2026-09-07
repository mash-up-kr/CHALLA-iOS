import CHALLANetwork
import Foundation
import os

/// 구독 요청만 기록하고 이벤트는 흘리지 않는 스텁. 디코딩 검증에만 쓴다.
struct StubSTOMPClient: STOMPClienting {

    func subscribe(to _: String) async throws -> AsyncThrowingStream<STOMPEvent, any Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func applicationDidEnterBackground() async {}
    func applicationWillEnterForeground() async {}
}

/// 구독마다 지정한 스트림을 돌려주는 스텁. 합친 스트림의 종료 방식을 검증할 때 쓴다.
struct ScriptedSTOMPClient: STOMPClienting {

    /// destination을 받아 그 구독이 어떻게 끝날지 정한다.
    let outcome: @Sendable (String) -> Outcome

    enum Outcome {
        /// 구독 자체가 실패한다.
        case subscribeFails
        /// 열리자마자 오류로 끊긴다.
        case failsWith(any Error)
        /// 열렸다가 조용히 끝난다.
        case finishes
    }

    func subscribe(to destination: String) async throws -> AsyncThrowingStream<STOMPEvent, any Error> {
        switch outcome(destination) {
        case .subscribeFails:
            throw STOMPError.notConnected
        case let .failsWith(error):
            return AsyncThrowingStream { $0.finish(throwing: error) }
        case .finishes:
            return AsyncThrowingStream { $0.finish() }
        }
    }

    func applicationDidEnterBackground() async {}
    func applicationWillEnterForeground() async {}
}

/// 어떤 주소를 구독했는지만 기록하는 스텁.
final class RecordingSTOMPClient: STOMPClienting, Sendable {

    private let state = OSAllocatedUnfairLock(initialState: [String]())

    var destinations: [String] {
        state.withLock { $0 }
    }

    func subscribe(to destination: String) async throws -> AsyncThrowingStream<STOMPEvent, any Error> {
        state.withLock { $0.append(destination) }
        // 끝내지 않는다 — 실제 구독처럼 소비가 멈출 때까지 열려 있다.
        return AsyncThrowingStream { _ in }
    }

    func applicationDidEnterBackground() async {}
    func applicationWillEnterForeground() async {}
}
