import Dependencies
import DependenciesMacros

@DependencyClient
public struct FetchRoomCoverOptionsUseCase: Sendable {
    public var run: @Sendable () async throws -> RoomCoverOptions
}

extension FetchRoomCoverOptionsUseCase: TestDependencyKey {

    public static func live(repository: any RoomRepository) -> FetchRoomCoverOptionsUseCase {
        FetchRoomCoverOptionsUseCase(run: { try await repository.coverOptions() })
    }

    public static let testValue = FetchRoomCoverOptionsUseCase()

    public static let previewValue = FetchRoomCoverOptionsUseCase(run: { .preview })
}

public extension DependencyValues {
    var fetchRoomCoverOptionsUseCase: FetchRoomCoverOptionsUseCase {
        get { self[FetchRoomCoverOptionsUseCase.self] }
        set { self[FetchRoomCoverOptionsUseCase.self] = newValue }
    }
}
