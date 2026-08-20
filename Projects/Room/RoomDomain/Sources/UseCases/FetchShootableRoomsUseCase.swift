import Dependencies
import DependenciesMacros

/// 촬영 가능한 방 목록. 카메라 진입 시 방 선택 드로어의 재료가 된다.
///
/// `liveValue`가 없는 이유는 `FetchRoomsUseCase` 주석 참고 — 조립은 실행 앱의 `CompositionRoot`가 맡는다.
@DependencyClient
public struct FetchShootableRoomsUseCase: Sendable {
    public var run: @Sendable () async throws -> [ShootableRoom]
}

extension FetchShootableRoomsUseCase: TestDependencyKey {

    public static func live(repository: any RoomRepository) -> FetchShootableRoomsUseCase {
        FetchShootableRoomsUseCase(run: { try await repository.shootableRooms() })
    }

    public static let testValue = FetchShootableRoomsUseCase()

    public static let previewValue = FetchShootableRoomsUseCase(
        run: { ShootableRoom.previewRooms }
    )
}

public extension DependencyValues {
    var fetchShootableRoomsUseCase: FetchShootableRoomsUseCase {
        get { self[FetchShootableRoomsUseCase.self] }
        set { self[FetchShootableRoomsUseCase.self] = newValue }
    }
}
