import Dependencies
import DependenciesMacros

/// 사진에 리액션을 남긴다. 서버가 갱신 사진을 주지 않으므로 반환값은 없다 —
/// 화면 갱신은 호출부가 낙관적으로 반영한다.
@DependencyClient
public struct SetPhotoReactionUseCase: Sendable {
    public var run: @Sendable (_ roomID: Int64, _ photoID: String, _ kind: ReactionKind, _ isOn: Bool) async throws -> Void
}

extension SetPhotoReactionUseCase: TestDependencyKey {

    public static func live(repository: any PhotoRepository) -> SetPhotoReactionUseCase {
        SetPhotoReactionUseCase(run: { roomID, photoID, kind, isOn in
            try await repository.setReaction(roomID: roomID, photoID: photoID, kind: kind, isOn: isOn)
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
