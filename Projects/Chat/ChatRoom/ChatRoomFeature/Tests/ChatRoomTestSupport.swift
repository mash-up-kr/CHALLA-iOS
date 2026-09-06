import ChatDomain
import ChatRoomFeature
import ComposableArchitecture
import Foundation

enum Fixture {
    static let roomID: Int64 = -1
    static let roomTitle = "해피하우스 강릉 여행"
    static let currentUserID: Int64 = 7
    static let currentUserNickname = "아이스크림연준"
    static let otherUserID: Int64 = 8

    /// 전송 시 낙관적 메시지가 받는 결정적 시각(makeChatStore가 date를 이 값으로 고정한다).
    static let sendDate = Date(timeIntervalSince1970: 1_784_000_100)

    static func message(
        chatID: Int64,
        kind: ChatMessage.Kind = .text,
        content: String = "메시지",
        authorID: Int64 = otherUserID,
        author: String = "그린그린엄성현",
        createdAt: Date = Date(timeIntervalSince1970: 1_784_000_040)
    ) -> ChatMessage {
        ChatMessage(
            id: .server(chatID),
            kind: kind,
            content: content,
            authorID: authorID,
            authorName: author,
            createdAt: createdAt
        )
    }

    /// 전송 시 화면이 만드는 낙관적 메시지 (uuid=.incrementing, date=sendDate 고정 기준).
    static func optimistic(content: String, uuidIndex: Int = 0) -> ChatMessage {
        ChatMessage(
            id: .local(UUID(uuidIndex)),
            kind: .text,
            content: content,
            authorID: currentUserID,
            authorName: currentUserNickname,
            createdAt: sendDate
        )
    }
}

@MainActor
func makeChatStore(
    messages: @escaping @Sendable (Int64, Int, Int) async throws -> [ChatMessage] = { _, _, _ in [] },
    send: @escaping @Sendable (Int64, Int64?, String) async throws -> Int64? = { _, _, _ in
        throw ChatError.unknown
    },
    // 기본은 "소켓 없음" — 대부분의 테스트는 REST 경로만 본다.
    // 구독이 실패하면 화면은 얼럿 없이 REST로만 돌아야 하고, 그 경로가 여기서 함께 검증된다.
    observe: @escaping @Sendable (Int64) async throws -> AsyncThrowingStream<ChatStreamEvent, any Error> = { _ in
        throw ChatError.network
    }
) -> TestStoreOf<ChatRoomFeature> {
    TestStore(
        initialState: ChatRoomFeature.State(
            roomID: Fixture.roomID,
            roomTitle: Fixture.roomTitle,
            currentUserID: Fixture.currentUserID,
            currentUserNickname: Fixture.currentUserNickname,
            isPrinted: true
        )
    ) {
        ChatRoomFeature()
    } withDependencies: {
        $0.fetchChatsUseCase = FetchChatsUseCase(run: messages)
        $0.sendChatUseCase = SendChatUseCase(run: send)
        $0.observeChatsUseCase = ObserveChatsUseCase(run: observe)
        $0.uuid = .incrementing // 낙관적 메시지 id를 결정적으로
        $0.date = .constant(Fixture.sendDate)
    }
}
