import Dependencies
import DependenciesMacros

/// 채팅 ID로 사진의 이모지 리액션을 삭제한다.
@DependencyClient
public struct DeletePhotoReactionUseCase: Sendable {
    public var run: @Sendable (_ chatID: Int64) async throws -> Void
}

extension DeletePhotoReactionUseCase: TestDependencyKey {

    public static func live(repository: any PhotoRepository) -> DeletePhotoReactionUseCase {
        DeletePhotoReactionUseCase(run: { chatID in
            try await repository.deleteReaction(chatID: chatID)
        })
    }

    public static let testValue = DeletePhotoReactionUseCase()
}

public extension DependencyValues {
    var deletePhotoReactionUseCase: DeletePhotoReactionUseCase {
        get { self[DeletePhotoReactionUseCase.self] }
        set { self[DeletePhotoReactionUseCase.self] = newValue }
    }
}
