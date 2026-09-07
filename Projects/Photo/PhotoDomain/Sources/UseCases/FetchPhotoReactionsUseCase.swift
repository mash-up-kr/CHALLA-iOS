import Dependencies
import DependenciesMacros

/// 사진 한 장의 리액션(스티커·칩 띠)을 가져온다. 사진을 펼칠 때만 호출해 목록의 1+N을 피한다.
@DependencyClient
public struct FetchPhotoReactionsUseCase: Sendable {
    public var run: @Sendable (_ photoID: String) async throws -> PhotoReactions
}

extension FetchPhotoReactionsUseCase: TestDependencyKey {

    public static func live(repository: any PhotoRepository) -> FetchPhotoReactionsUseCase {
        FetchPhotoReactionsUseCase(run: { photoID in
            try await repository.reactions(forPhotoID: photoID)
        })
    }

    public static let testValue = FetchPhotoReactionsUseCase()

    public static let previewValue = FetchPhotoReactionsUseCase(run: { _ in PhotoReactions() })
}

public extension DependencyValues {
    var fetchPhotoReactionsUseCase: FetchPhotoReactionsUseCase {
        get { self[FetchPhotoReactionsUseCase.self] }
        set { self[FetchPhotoReactionsUseCase.self] = newValue }
    }
}
