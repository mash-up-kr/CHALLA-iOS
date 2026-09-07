import Dependencies
import DependenciesMacros

/// 방의 채팅을 페이지 단위로 가져온다.
@DependencyClient
public struct FetchChatsUseCase: Sendable {
    public var run: @Sendable (_ roomID: Int64, _ page: Int, _ size: Int) async throws -> [ChatMessage]
}

extension FetchChatsUseCase: TestDependencyKey {

    public static func live(repository: any ChatRepository) -> FetchChatsUseCase {
        FetchChatsUseCase(run: { roomID, page, size in
            try await repository.messages(inRoom: roomID, page: page, size: size)
        })
    }

    public static let testValue = FetchChatsUseCase()

    public static let previewValue = FetchChatsUseCase(run: { _, _, _ in [] })
}

public extension DependencyValues {
    var fetchChatsUseCase: FetchChatsUseCase {
        get { self[FetchChatsUseCase.self] }
        set { self[FetchChatsUseCase.self] = newValue }
    }
}
