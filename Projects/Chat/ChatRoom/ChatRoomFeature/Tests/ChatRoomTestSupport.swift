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
    pages: (@Sendable (Int64, Int, Int) async throws -> ChatPage)? = nil,
    send: @escaping @Sendable (Int64, Int64?, String) async throws -> Int64? = { _, _, _ in
        throw ChatError.unknown
    },
    // 기본은 이벤트 없이 바로 끝나는 스트림 — 정상 종료는 아무 액션도 내지 않아 흐름이 단순하다.
    // 구독 실패 경로는 observe를 던지게 넘겨 전용 테스트에서 본다.
    observe: @escaping @Sendable (Int64) async throws -> AsyncThrowingStream<ChatStreamEvent, any Error> = { _ in
        AsyncThrowingStream { $0.finish() }
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
        $0.fetchChatsUseCase = FetchChatsUseCase(run: pages ?? { roomID, page, size in
            let messages = try await messages(roomID, page, size)
            return ChatPage(messages: messages, nextPage: page + 1, hasMore: messages.count >= size)
        })
        $0.sendChatUseCase = SendChatUseCase(run: send)
        $0.observeChatsUseCase = ObserveChatsUseCase(run: observe)
        $0.continuousClock = ImmediateClock()
        $0.uuid = .incrementing // 낙관적 메시지 id를 결정적으로
        $0.date = .constant(Fixture.sendDate)
    }
}
