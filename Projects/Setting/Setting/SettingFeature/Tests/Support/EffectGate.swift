import Foundation

/// 이펙트를 원하는 시점까지 붙잡아 두는 문.
/// "처리 중"·"조회가 떠 있는 중" 상태를 만들 때 의존성 클로저 안에서 쓴다.
struct EffectGate: Sendable {

    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        (stream, continuation) = AsyncStream<Void>.makeStream()
    }

    /// `open()`을 부를 때까지 돌아오지 않는다. 이펙트가 취소되면 그 즉시 빠져나온다.
    func wait() async {
        for await _ in stream {}
    }

    func open() {
        continuation.finish()
    }
}
