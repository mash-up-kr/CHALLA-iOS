import Dependencies
import DependenciesMacros

/// 방의 인화된 사진을 찍힌 순서대로 가져온다.
@DependencyClient
public struct FetchRoomPhotosUseCase: Sendable {
    public var run: @Sendable (_ roomID: Int64) async throws -> [Photo]
}

extension FetchRoomPhotosUseCase: TestDependencyKey {

    public static func live(repository: any PhotoRepository) -> FetchRoomPhotosUseCase {
        FetchRoomPhotosUseCase(run: { roomID in
            try await repository.photos(inRoom: roomID)
        })
    }

    public static let testValue = FetchRoomPhotosUseCase()

    public static let previewValue = FetchRoomPhotosUseCase(run: { _ in [] })
}

public extension DependencyValues {
    var fetchRoomPhotosUseCase: FetchRoomPhotosUseCase {
        get { self[FetchRoomPhotosUseCase.self] }
        set { self[FetchRoomPhotosUseCase.self] = newValue }
    }
}
