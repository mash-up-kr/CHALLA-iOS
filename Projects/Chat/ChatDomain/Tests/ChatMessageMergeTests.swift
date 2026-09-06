import ChatDomain
import Foundation
import Testing

@Suite("ChatMessage.merged — 목록 병합")
struct ChatMessageMergeTests {

    private func server(_ chatID: Int64, at seconds: TimeInterval, content: String = "메시지") -> ChatMessage {
        ChatMessage(
            id: .server(chatID),
            kind: .text,
            content: content,
            authorID: 8,
            authorName: "성현",
            createdAt: Date(timeIntervalSince1970: seconds)
        )
    }

    private func local(_ uuidIndex: Int, at seconds: TimeInterval) -> ChatMessage {
        ChatMessage(
            id: .local(UUID(uuidIndex)),
            kind: .text,
            content: "보내는 중",
            authorID: 7,
            authorName: "연준",
            createdAt: Date(timeIntervalSince1970: seconds)
        )
    }

    @Test("같은 chatId는 한 번만 남고 새로 받은 쪽이 이긴다")
    func dedupesByServerID() {
        let existing = [server(1, at: 100, content: "옛 값")]
        let incoming = [server(1, at: 100, content: "새 값")]

        let merged = ChatMessage.merged(existing, with: incoming)
        #expect(merged.count == 1)
        #expect(merged[0].content == "새 값")
    }

    @Test("아직 전송 중인 로컬 메시지는 새 목록에 없어도 남는다")
    func keepsPendingLocalMessage() {
        let merged = ChatMessage.merged([local(0, at: 200)], with: [server(1, at: 100)])
        #expect(merged.map(\.id) == [.server(1), .local(UUID(0))])
    }

    @Test("시간 오름차순으로 정렬한다 (최신이 아래)")
    func sortsAscending() {
        let merged = ChatMessage.merged([], with: [server(2, at: 200), server(1, at: 100)])
        #expect(merged.map(\.id) == [.server(1), .server(2)])
    }

    @Test("같은 시각이면 chatId 순으로 고정된다 (병합할 때마다 자리가 바뀌지 않게)")
    func stableOrderOnEqualTimestamps() {
        let first = ChatMessage.merged([], with: [server(3, at: 100), server(1, at: 100), server(2, at: 100)])
        let second = ChatMessage.merged(first, with: [server(2, at: 100)])

        #expect(first.map(\.id) == [.server(1), .server(2), .server(3)])
        #expect(second.map(\.id) == first.map(\.id))
    }

    @Test("같은 시각의 낙관적 메시지는 맨 뒤에 둔다 (방금 입력한 것)")
    func localGoesLastWithinSameInstant() {
        let merged = ChatMessage.merged([local(0, at: 100)], with: [server(9, at: 100)])
        #expect(merged.map(\.id) == [.server(9), .local(UUID(0))])
    }

    @Test("확정된 내 메시지와 소켓으로 되돌아온 같은 메시지가 한 건으로 합쳐진다")
    func promotedMessageAbsorbsSocketEcho() {
        let confirmed = local(0, at: 100).promoted(toServerID: 5)
        let echo = server(5, at: 100, content: "보내는 중")

        let merged = ChatMessage.merged([confirmed], with: [echo])
        #expect(merged.count == 1)
        #expect(merged[0].id == .server(5))
    }

    @Test("이전 페이지를 붙일 때 이미 있는 메시지가 중복되지 않는다")
    func prependingOlderPageDoesNotDuplicate() {
        let existing = [server(10, at: 1000), server(11, at: 1100)]
        let olderPage = [server(9, at: 900), server(10, at: 1000)]

        let merged = ChatMessage.merged(existing, with: olderPage)
        #expect(merged.map(\.id) == [.server(9), .server(10), .server(11)])
    }
}
