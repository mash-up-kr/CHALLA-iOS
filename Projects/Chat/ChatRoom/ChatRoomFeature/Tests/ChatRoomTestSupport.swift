import ChatDomain
import ChatRoomFeature
import ComposableArchitecture
import Foundation

enum Fixture {
    static let roomID: Int64 = -1
    static let roomTitle = "해피하우스 강릉 여행"
    static let currentUserNickname = "아이스크림연준"

    /// 전송 시 낙관적 메시지가 받는 결정적 시각(makeChatStore가 date를 이 값으로 고정한다).
    static let sendDate = Date(timeIntervalSince1970: 1_784_000_100)

    static func message(
        id: UUID = UUID(),
        kind: ChatMessage.Kind = .text,
        content: String = "메시지",
        author: String = "그린그린엄성현",
        createdAt: Date = Date(timeIntervalSince1970: 1_784_000_040)
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            kind: kind,
            content: content,
            authorName: author,
            createdAt: createdAt
        )
    }
}

@MainActor
func makeChatStore(
    messages: @escaping @Sendable (Int64, Int, Int) async throws -> [ChatMessage] = { _, _, _ in [] },
    send: @escaping @Sendable (Int64, Int64?, String) async throws -> Void = { _, _, _ in
        throw ChatError.unknown
    }
) -> TestStoreOf<ChatRoomFeature> {
    TestStore(
        initialState: ChatRoomFeature.State(
            roomID: Fixture.roomID,
            roomTitle: Fixture.roomTitle,
            currentUserNickname: Fixture.currentUserNickname,
            isPrinted: true
        )
    ) {
        ChatRoomFeature()
    } withDependencies: {
        $0.fetchChatsUseCase = FetchChatsUseCase(run: messages)
        $0.sendChatUseCase = SendChatUseCase(run: send)
        $0.uuid = .incrementing // 낙관적 메시지 id를 결정적으로
        $0.date = .constant(Fixture.sendDate)
    }
}
