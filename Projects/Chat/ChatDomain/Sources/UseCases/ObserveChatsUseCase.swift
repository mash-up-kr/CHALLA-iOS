import Dependencies
import DependenciesMacros

/// 방 채팅을 실시간으로 받는다. 구독이 확정된 뒤 스트림을 돌려준다.
@DependencyClient
public struct ObserveChatsUseCase: Sendable {
    public var run: @Sendable (_ roomID: Int64) async throws -> AsyncThrowingStream<ChatStreamEvent, any Error>
}

extension ObserveChatsUseCase: TestDependencyKey {

    public static func live(streaming: any ChatEventStreaming) -> ObserveChatsUseCase {
        ObserveChatsUseCase(run: { roomID in
            try await streaming.chatEvents(roomID: roomID)
        })
    }

    public static let testValue = ObserveChatsUseCase()

    /// 이벤트가 오지 않고 끝나지도 않는 스트림 — 프리뷰·데모의 구독 자리를 채운다.
    public static let previewValue = ObserveChatsUseCase(run: { _ in
        AsyncThrowingStream { _ in }
    })
}

public extension DependencyValues {
    var observeChatsUseCase: ObserveChatsUseCase {
        get { self[ObserveChatsUseCase.self] }
        set { self[ObserveChatsUseCase.self] = newValue }
    }
}
