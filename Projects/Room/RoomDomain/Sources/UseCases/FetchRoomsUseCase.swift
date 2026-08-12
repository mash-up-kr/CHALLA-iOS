import Dependencies
import DependenciesMacros

/// 내가 속한 방 목록. 홈의 화면 4상태가 이 결과 하나에서 갈린다.
///
/// `liveValue`가 없는 것은 의도다 — 실 구현에 `RoomData`의 저장소가 필요해 Domain이 Data를
/// import하게 된다. 조립은 실행 앱의 `CompositionRoot`가 맡는다 (세 UseCase 모두 같다).
@DependencyClient
public struct FetchRoomsUseCase: Sendable {
    public var run: @Sendable () async throws -> [Room]
}

extension FetchRoomsUseCase: TestDependencyKey {

    public static func live(repository: any RoomRepository) -> FetchRoomsUseCase {
        FetchRoomsUseCase(run: { try await repository.rooms() })
    }

    public static let testValue = FetchRoomsUseCase()

    public static let previewValue = FetchRoomsUseCase(
        run: { Room.previewRooms }
    )
}

public extension DependencyValues {
    var fetchRoomsUseCase: FetchRoomsUseCase {
        get { self[FetchRoomsUseCase.self] }
        set { self[FetchRoomsUseCase.self] = newValue }
    }
}
