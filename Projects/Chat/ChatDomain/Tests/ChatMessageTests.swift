import ChatDomain
import Foundation
import Testing

@Suite("ChatMessage — 내 메시지 판별")
struct ChatMessageTests {

    private func message(author: String) -> ChatMessage {
        ChatMessage(
            id: UUID(),
            kind: .text,
            content: "메시지",
            authorName: author,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    @Test("닉네임이 authorName과 같으면 내 메시지다")
    func mineWhenNicknameMatches() {
        #expect(message(author: "연준").isMine(currentUserNickname: "연준"))
    }

    @Test("닉네임이 다르면 내 메시지가 아니다")
    func notMineWhenNicknameDiffers() {
        #expect(!message(author: "성현").isMine(currentUserNickname: "연준"))
    }

    @Test("authorName이 비어 있으면 내 메시지가 아니다 (빈 닉네임끼리 오판 방지)")
    func notMineWhenAuthorEmpty() {
        #expect(!message(author: "").isMine(currentUserNickname: ""))
    }
}
