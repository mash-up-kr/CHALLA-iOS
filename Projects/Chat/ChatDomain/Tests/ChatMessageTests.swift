import ChatDomain
import Foundation
import Testing

@Suite("ChatMessage — 내 메시지 판별")
struct ChatMessageTests {

    private func message(authorID: Int64, authorName: String = "연준") -> ChatMessage {
        ChatMessage(
            id: .server(1),
            kind: .text,
            content: "메시지",
            authorID: authorID,
            authorName: authorName,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    @Test("userId가 같으면 내 메시지다")
    func mineWhenUserIDMatches() {
        #expect(message(authorID: 7).isMine(currentUserID: 7))
    }

    @Test("userId가 다르면 내 메시지가 아니다")
    func notMineWhenUserIDDiffers() {
        #expect(!message(authorID: 8).isMine(currentUserID: 7))
    }

    @Test("닉네임이 같아도 userId가 다르면 내 메시지가 아니다 (동명이인 오판 방지)")
    func notMineWhenOnlyNicknameMatches() {
        #expect(!message(authorID: 8, authorName: "연준").isMine(currentUserID: 7))
    }

    @Test("전송 응답의 chatId로 낙관적 메시지를 서버 id로 확정한다")
    func promotesLocalMessage() {
        let local = ChatMessage(
            id: .local(UUID(0)),
            kind: .text,
            content: "보냄",
            authorID: 7,
            authorName: "연준",
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let promoted = local.promoted(toServerID: 42)

        #expect(promoted.id == .server(42))
        #expect(promoted.content == local.content)
        #expect(promoted.createdAt == local.createdAt)
    }
}
