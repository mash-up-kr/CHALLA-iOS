import Dependencies
import DependenciesMacros

/// 내가 속한 방 목록을 한 번에 가져온다. 홈의 화면 4상태는 이 결과 하나에서 파생된다.
///
/// UseCase는 화면이 Domain을 부르는 유일한 창구다. Feature는 `RoomRepository`를 직접
/// 알지 못하고 `@Dependency(\.fetchRoomsUseCase)`로 이 타입만 꺼내 쓴다.
///
/// `liveValue`가 없는 것은 의도다 — 실 구현을 만들려면 `RoomData`의 구체 저장소가
/// 필요한데, 그러면 Domain이 Data를 import하게 되어 의존 방향이 뒤집힌다.
/// 대신 `.live(repository:)` 팩토리를 두고 조립은 실행 앱의 `CompositionRoot`가 맡는다.
/// (세 UseCase 모두 같은 구조다. 자세한 배경은 `MODULE.md`.)
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
