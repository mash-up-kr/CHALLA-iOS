import ChatDomain
import Foundation

/// 데모용 채팅 저장소. 조회는 메모리 픽스처, 전송은 메모리에 쌓아 재조회 없이도 목록에 남긴다.
struct DemoChatRepository: ChatRepository {

    enum Scenario {
        case populated(DemoChatStore)
        case neverFinishes
        case empty
        case failure(ChatError)
    }

    let scenario: Scenario
    /// 응답이 즉시 오면 로딩 표시를 볼 수 없어 일부러 늦춘다.
    private let latency: Duration = .milliseconds(500)

    func messages(inRoom _: Int64, page: Int, size: Int) async throws -> ChatPage {
        switch scenario {
        case let .populated(store):
            try await Task.sleep(for: latency)
            // 실서버처럼 최신 메시지가 page 0에 오도록 정렬한 뒤 자른다.
            let messages = await store.all().sorted { $0.createdAt > $1.createdAt }
            let start = min(page * size, messages.count)
            let end = min(start + size, messages.count)
            return ChatPage(
                messages: Array(messages[start ..< end]),
                nextPage: page + 1,
                hasMore: end < messages.count
            )

        case .neverFinishes:
            try await Task.sleep(for: .seconds(60 * 60))
            return ChatPage(messages: [], nextPage: page + 1, hasMore: false)

        case .empty:
            try await Task.sleep(for: latency)
            return ChatPage(messages: [], nextPage: page + 1, hasMore: false)

        case let .failure(error):
            try await Task.sleep(for: latency)
            throw error
        }
    }

    @discardableResult
    func send(roomID _: Int64, photoID _: Int64?, content: String) async throws -> Int64? {
        guard case let .populated(store) = scenario else { throw ChatError.unknown }
        try await Task.sleep(for: latency)

        // 서버가 없으니 재진입(재조회) 시에도 남도록 저장소에 넣어 둔다. 화면은 낙관적 메시지를 따로 그린다.
        let chatID = DemoFixture.makeChatID()
        let message = ChatMessage(
            id: .server(chatID),
            kind: .text,
            content: content,
            authorID: DemoFixture.currentUserID,
            authorName: DemoFixture.currentUserNickname,
            createdAt: Date()
        )
        await store.append(message)
        return chatID
    }
}
