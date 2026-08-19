import Foundation

/// 토큰 갱신이 최종 실패해 재로그인이 필요해졌음을 앱 상위로 알리는 단방향 채널.
///
/// 갱신은 네트워크 레이어 깊은 곳(요청 재시도 경로)에서 일어나므로 호출 스택으로는 화면까지 오류가 올라오지 않는다.
/// 세션이 끊긴 사실만 흘려보내고, 어느 화면으로 보낼지는 받는 쪽(앱)이 정한다.
public final class SessionExpirationChannel: Sendable {

    /// 소비자는 앱 루트 하나다 — 놓친 알림이 쌓여 여러 번 처리되지 않도록 최신 하나만 버퍼링한다.
    public let events: AsyncStream<Void>

    private let continuation: AsyncStream<Void>.Continuation

    public init() {
        (events, continuation) = AsyncStream.makeStream(
            of: Void.self,
            bufferingPolicy: .bufferingNewest(1)
        )
    }

    public func notify() {
        continuation.yield(())
    }

    public func finish() {
        continuation.finish()
    }
}
