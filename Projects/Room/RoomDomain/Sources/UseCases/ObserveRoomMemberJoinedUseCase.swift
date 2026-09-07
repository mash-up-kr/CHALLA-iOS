import Dependencies
import DependenciesMacros

/// 내가 속한 방들의 참여 이벤트를 한 스트림으로 받는다.
@DependencyClient
public struct ObserveRoomMemberJoinedUseCase: Sendable {
    public var run: @Sendable (_ roomIDs: [Room.ID]) async throws
        -> AsyncThrowingStream<RoomMemberJoinedEvent, any Error>
}

extension ObserveRoomMemberJoinedUseCase: TestDependencyKey {

    public static func live(streaming: any RoomEventStreaming) -> ObserveRoomMemberJoinedUseCase {
        ObserveRoomMemberJoinedUseCase(run: { roomIDs in
            try await streaming.memberJoinedEvents(inRooms: roomIDs)
        })
    }

    public static let testValue = ObserveRoomMemberJoinedUseCase()

    /// 이벤트가 오지 않고 끝나지도 않는 스트림 — 프리뷰·데모의 구독 자리를 채운다.
    public static let previewValue = ObserveRoomMemberJoinedUseCase(run: { _ in
        AsyncThrowingStream { _ in }
    })
}

public extension DependencyValues {
    var observeRoomMemberJoinedUseCase: ObserveRoomMemberJoinedUseCase {
        get { self[ObserveRoomMemberJoinedUseCase.self] }
        set { self[ObserveRoomMemberJoinedUseCase.self] = newValue }
    }
}
