import CHALLANetwork
import Foundation

/// 구독 요청만 기록하고 이벤트는 흘리지 않는 스텁. 디코딩 검증에만 쓴다.
struct StubSTOMPClient: STOMPClienting {

    func subscribe(to _: String) async throws -> AsyncThrowingStream<STOMPEvent, any Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func applicationDidEnterBackground() async {}
    func applicationWillEnterForeground() async {}
}
