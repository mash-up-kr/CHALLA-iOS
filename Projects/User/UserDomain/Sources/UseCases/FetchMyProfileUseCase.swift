import Dependencies
import DependenciesMacros

@DependencyClient
public struct FetchMyProfileUseCase: Sendable {
    public var run: @Sendable () async throws -> UserProfile
}

extension FetchMyProfileUseCase: TestDependencyKey {

    public static func live(repository: any UserRepository) -> FetchMyProfileUseCase {
        FetchMyProfileUseCase(run: { try await repository.fetchMyProfile() })
    }

    public static let testValue = FetchMyProfileUseCase()

    public static let previewValue = FetchMyProfileUseCase(
        run: { UserProfile(id: 1, nickname: "찰나") }
    )
}

public extension DependencyValues {
    var fetchMyProfileUseCase: FetchMyProfileUseCase {
        get { self[FetchMyProfileUseCase.self] }
        set { self[FetchMyProfileUseCase.self] = newValue }
    }
}
