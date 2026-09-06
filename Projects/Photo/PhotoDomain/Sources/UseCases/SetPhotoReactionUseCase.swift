import Dependencies
import DependenciesMacros

/// 사진에 리액션을 등록하고 채팅 ID를 반환한다. 응답에 ID가 없으면 nil이다.
@DependencyClient
public struct SetPhotoReactionUseCase: Sendable {
    public var run: @Sendable (_ roomID: Int64, _ photoID: String, _ kind: ReactionKind) async throws -> Int64?
}

extension SetPhotoReactionUseCase: TestDependencyKey {

    public static func live(repository: any PhotoRepository) -> SetPhotoReactionUseCase {
        SetPhotoReactionUseCase(run: { roomID, photoID, kind in
            try await repository.setReaction(roomID: roomID, photoID: photoID, kind: kind)
        })
    }

    public static let testValue = SetPhotoReactionUseCase()
}

public extension DependencyValues {
    var setPhotoReactionUseCase: SetPhotoReactionUseCase {
        get { self[SetPhotoReactionUseCase.self] }
        set { self[SetPhotoReactionUseCase.self] = newValue }
    }
}
