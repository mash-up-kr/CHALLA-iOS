import Foundation

public extension ChatMessage {

    /// 화면이 들고 있는 목록에 새로 받은 목록(REST 페이지 또는 소켓 한 건)을 합친다.
    ///
    /// - 같은 id면 새로 받은 쪽이 이긴다. 서버 값이 정본이다.
    /// - 아직 전송 중인 `.local` 메시지는 새 목록에 없어도 그대로 남는다.
    /// - 정렬 키가 `(createdAt, 서버 id)`인 이유: `Array.sorted`는 stable하지 않아,
    ///   시각만으로 정렬하면 같은 시각의 두 건이 병합할 때마다 자리를 바꿔 목록이 흔들린다.
    /// - Parameter absorbingPendingSends: 방금 서버에서 되돌아온 **내 메시지**를 합칠 때만 켠다.
    ///   과거 목록을 붙일 때 켜면, 예전에 보낸 같은 글이 지금 전송 중인 메시지를 지워 버린다.
    static func merged(
        _ existing: [ChatMessage],
        with incoming: [ChatMessage],
        absorbingPendingSends: Bool = false
    ) -> [ChatMessage] {
        var byID: [ChatMessageID: ChatMessage] = [:]
        for message in existing {
            byID[message.id] = message
        }
        for message in incoming {
            // 이미 들고 있던 메시지가 다시 온 것이면 흡수하지 않는다.
            // 같은 글을 연달아 보냈을 때 첫 번째 메시지의 늦은 에코가
            // 아직 전송 중인 두 번째 메시지를 지워 버린다.
            let isNew = byID.updateValue(message, forKey: message.id) == nil
            if absorbingPendingSends, isNew, let stale = pendingLocalTwin(of: message, in: byID) {
                byID.removeValue(forKey: stale)
            }
        }
        return byID.values.sorted { orderingKey($0) < orderingKey($1) }
    }

    /// 서버에서 받은 메시지와 같은 것인데 아직 로컬 id로 남아 있는 낙관적 메시지를 찾는다.
    ///
    /// 전송 응답에 `chatId`가 실려 오면 화면이 낙관적 메시지를 그 id로 확정해서 이 일이 생기지 않는다.
    /// 그런데 서버가 `chatId`를 주지 않을 때가 있어, 그러면 로컬 메시지가 그대로 남고
    /// 소켓으로 되돌아온 같은 메시지가 새 줄로 붙어 **두 줄**이 된다.
    ///
    /// 시각은 보지 않는다. 기기 시계와 서버 시계가 어긋날 수 있기 때문이다.
    /// 대신 호출부가 "방금 되돌아온 내 메시지"일 때만, 그리고 그 메시지가
    /// 목록에 **처음 들어오는** 것일 때만 이 흡수를 켠다.
    private static func pendingLocalTwin(
        of message: ChatMessage,
        in messages: [ChatMessageID: ChatMessage]
    ) -> ChatMessageID? {
        guard case .server = message.id else { return nil }

        return messages.values
            .filter { candidate in
                if case .local = candidate.id {
                    return candidate.authorID == message.authorID
                        && candidate.content == message.content
                        && candidate.kind == message.kind
                }
                return false
            }
            // 여러 개면 가장 먼저 보낸 것부터 지운다 — 보낸 순서와 짝이 맞는다.
            .min { $0.createdAt < $1.createdAt }?
            .id
    }

    /// 낙관적 메시지는 같은 시각 안에서 맨 뒤에 둔다 — 방금 입력한 것이라 가장 나중이다.
    private static func orderingKey(_ message: ChatMessage) -> (Date, Int64) {
        switch message.id {
        case let .server(id): (message.createdAt, id)
        case .local: (message.createdAt, .max)
        }
    }
}
