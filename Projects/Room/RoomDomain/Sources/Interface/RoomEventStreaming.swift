import Foundation

/// 방에서 일어나는 일을 실시간으로 받는 창구. 구현은 `RoomData`가 맡는다.
///
/// 조회·저장(`RoomRepository`)과 계약을 나눈 이유: 수명주기도 실패 양상도 다르고,
/// 기존 Mock·인메모리 구현들이 쓰지도 않을 메서드를 떠안지 않게 하려는 것이다.
public protocol RoomEventStreaming: Sendable {

    /// 내가 속한 방들의 참여 이벤트를 **한 스트림으로** 받는다.
    /// 어느 방 것인지는 이벤트가 들고 있으므로 받는 쪽이 가려 쓴다.
    ///
    /// 구현은 사용자 단위 주소 하나로 받으므로 `roomIDs`를 주소로 쓰지 않는다.
    /// 그래도 인자로 두는 이유는 방 목록이 바뀌면 구독을 다시 걸어야 하기 때문이다 —
    /// 로그아웃·재로그인·마지막 방 퇴장에 구독이 따라 움직여야 한다.
    func memberJoinedEvents(inRooms roomIDs: [Room.ID]) async throws
        -> AsyncThrowingStream<RoomMemberJoinedEvent, any Error>
}
