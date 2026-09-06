import Foundation

/// 방에서 일어나는 일을 실시간으로 받는 창구. 구현은 `RoomData`가 맡는다.
///
/// 조회·저장(`RoomRepository`)과 계약을 나눈 이유: 수명주기도 실패 양상도 다르고,
/// 기존 Mock·인메모리 구현들이 쓰지도 않을 메서드를 떠안지 않게 하려는 것이다.
public protocol RoomEventStreaming: Sendable {

    /// 내가 속한 방들의 참여 이벤트를 **한 스트림으로** 받는다.
    /// 어느 방 것인지는 이벤트가 들고 있으므로 받는 쪽이 가려 쓴다.
    ///
    /// `roomIDs`가 필요한 이유는 지금 서버가 방 단위 주소만 주기 때문이다
    /// (`/topic/room/{roomId}/member-joined`). 사용자 단위 주소가 생기면 구현이 이 값을 무시하고
    /// 구독 하나로 끝낸다 — 이 계약과 호출부는 그대로 둔 채 구현만 바뀐다.
    func memberJoinedEvents(inRooms roomIDs: [Room.ID]) async throws
        -> AsyncThrowingStream<RoomMemberJoinedEvent, any Error>
}
