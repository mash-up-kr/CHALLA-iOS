import Foundation

/// 소켓으로 흘러오는 채팅 이벤트.
public enum ChatStreamEvent: Sendable, Equatable {

    case message(ChatMessage)

    /// 끊겼다 다시 붙었다. 끊겨 있던 동안의 메시지는 오지 않으므로 그 구간을 REST로 메워야 한다.
    case resumed
}

/// 방 채팅 실시간 수신 창구. 구현은 `ChatData`가 맡는다.
///
/// 조회·전송(`ChatRepository`)과 계약을 나눈 이유: 수명주기도 실패 양상도 다르고,
/// 기존 Mock 구현들이 쓰지도 않을 메서드를 떠안지 않게 하려는 것이다.
public protocol ChatEventStreaming: Sendable {

    /// 구독이 확정된 뒤에 리턴한다 — 리턴 이후 시작한 REST 조회는 이벤트를 놓치지 않는다.
    /// 스트림 소비가 끝나면 구독 해제까지 구현체가 알아서 한다.
    func chatEvents(roomID: Int64) async throws -> AsyncThrowingStream<ChatStreamEvent, any Error>
}
