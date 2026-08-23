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

    func messages(inRoom _: Int64, page _: Int, size _: Int) async throws -> [ChatMessage] {
        switch scenario {
        case let .populated(store):
            try await Task.sleep(for: latency)
            return await store.all()

        case .neverFinishes:
            try await Task.sleep(for: .seconds(60 * 60))
            return []

        case .empty:
            try await Task.sleep(for: latency)
            return []

        case let .failure(error):
            try await Task.sleep(for: latency)
            throw error
        }
    }

    func send(roomID _: Int64, photoID _: Int64?, content: String) async throws {
        guard case let .populated(store) = scenario else { throw ChatError.unknown }
        try await Task.sleep(for: latency)

        // 서버가 없으니 재진입(재조회) 시에도 남도록 저장소에 넣어 둔다. 화면은 낙관적 메시지를 따로 그린다.
        let message = ChatMessage(
            id: UUID(),
            kind: .text,
            content: content,
            authorName: DemoFixture.currentUserNickname,
            createdAt: Date()
        )
        await store.append(message)
    }
}
