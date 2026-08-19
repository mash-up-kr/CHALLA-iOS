import Dependencies
import DependenciesMacros

/// 사진의 리액션을 켜거나 끄고 갱신된 사진을 돌려준다.
@DependencyClient
public struct SetPhotoReactionUseCase: Sendable {
    public var run: @Sendable (_ photoID: String, _ kind: ReactionKind, _ isOn: Bool) async throws -> Photo
}

extension SetPhotoReactionUseCase: TestDependencyKey {

    public static func live(repository: any PhotoRepository) -> SetPhotoReactionUseCase {
        SetPhotoReactionUseCase(run: { photoID, kind, isOn in
            try await repository.setReaction(photoID: photoID, kind: kind, isOn: isOn)
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
