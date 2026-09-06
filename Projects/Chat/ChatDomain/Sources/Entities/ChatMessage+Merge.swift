import Foundation

public extension ChatMessage {

    /// 화면이 들고 있는 목록에 새로 받은 목록(REST 페이지 또는 소켓 한 건)을 합친다.
    ///
    /// - 같은 id면 새로 받은 쪽이 이긴다. 서버 값이 정본이다.
    /// - 아직 전송 중인 `.local` 메시지는 새 목록에 없어도 그대로 남는다.
    /// - 정렬 키가 `(createdAt, 서버 id)`인 이유: `Array.sorted`는 stable하지 않아,
    ///   시각만으로 정렬하면 같은 시각의 두 건이 병합할 때마다 자리를 바꿔 목록이 흔들린다.
    static func merged(_ existing: [ChatMessage], with incoming: [ChatMessage]) -> [ChatMessage] {
        var byID: [ChatMessageID: ChatMessage] = [:]
        for message in existing {
            byID[message.id] = message
        }
        for message in incoming {
            byID[message.id] = message
        }
        return byID.values.sorted { orderingKey($0) < orderingKey($1) }
    }

    /// 낙관적 메시지는 같은 시각 안에서 맨 뒤에 둔다 — 방금 입력한 것이라 가장 나중이다.
    private static func orderingKey(_ message: ChatMessage) -> (Date, Int64) {
        switch message.id {
        case let .server(id): (message.createdAt, id)
        case .local: (message.createdAt, .max)
        }
    }
}
