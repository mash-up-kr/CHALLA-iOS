import Dependencies
import DependenciesMacros

/// 메시지를 보낸다. 성공 여부만 알린다 — 화면이 로컬 메시지를 낙관적으로 덧붙인다.
@DependencyClient
public struct SendChatUseCase: Sendable {
    public var run: @Sendable (_ roomID: Int64, _ photoID: Int64?, _ content: String) async throws -> Void
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
