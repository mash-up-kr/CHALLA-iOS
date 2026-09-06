import Dependencies
import DependenciesMacros

/// 사진 한 장의 리액션(스티커·칩 띠)을 가져온다. 사진을 펼칠 때만 호출해 목록의 1+N을 피한다.
@DependencyClient
public struct FetchPhotoReactionsUseCase: Sendable {
    public var run: @Sendable (_ roomID: Int64, _ photoID: String) async throws -> PhotoReactions
}

extension FetchPhotoReactionsUseCase: TestDependencyKey {

    public static func live(repository: any PhotoRepository) -> FetchPhotoReactionsUseCase {
        FetchPhotoReactionsUseCase(run: { roomID, photoID in
            try await repository.reactions(inRoom: roomID, photoID: photoID)
        })
    }

    public static let testValue = FetchPhotoReactionsUseCase()

    public static let previewValue = FetchPhotoReactionsUseCase(run: { _, _ in PhotoReactions() })
}

public extension DependencyValues {
    var fetchPhotoReactionsUseCase: FetchPhotoReactionsUseCase {
        get { self[FetchPhotoReactionsUseCase.self] }
        set { self[FetchPhotoReactionsUseCase.self] = newValue }
    }
}
