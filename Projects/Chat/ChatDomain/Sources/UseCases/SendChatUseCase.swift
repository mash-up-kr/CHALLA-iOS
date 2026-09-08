import Dependencies
import DependenciesMacros

/// 메시지를 보낸다. 서버가 만든 chatId를 돌려주면 화면이 낙관적 메시지를 그 id로 확정한다.
@DependencyClient
public struct SendChatUseCase: Sendable {
    public var run: @Sendable (_ roomID: Int64, _ photoID: Int64?, _ content: String) async throws -> Int64?
}

extension SendChatUseCase: TestDependencyKey {

    public static func live(repository: any ChatRepository) -> SendChatUseCase {
        SendChatUseCase(run: { roomID, photoID, content in
            try await repository.send(roomID: roomID, photoID: photoID, content: content)
        })
    }

    public static let testValue = SendChatUseCase()
}

public extension DependencyValues {
    var sendChatUseCase: SendChatUseCase {
        get { self[SendChatUseCase.self] }
        set { self[SendChatUseCase.self] = newValue }
    }
}
