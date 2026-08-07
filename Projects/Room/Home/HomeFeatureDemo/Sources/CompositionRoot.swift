import ComposableArchitecture
import RoomData // 앱 조립 지점이라 Data를 직접 import 한다 (아키텍처 규칙 2의 예외)
import RoomDomain

/// 의존성 조립 지점 — 데모앱에서 유일하게 Data 구현체를 만드는 곳.
///
/// 서버 스펙이 없어 실 구현 대신 `InMemoryRoomRepository`를 쓴다.
/// 스펙이 나오면 여기서 만드는 저장소만 바꾸면 되고 Feature는 손대지 않는다.
enum CompositionRoot {

    static func registerDependencies(for screen: DemoScreen, into values: inout DependencyValues) {
        let repository = makeRepository(for: screen)
        values.fetchRoomsUseCase = .live(repository: repository)
        values.createRoomUseCase = .live(repository: repository)
        values.joinRoomUseCase = .live(repository: repository)
    }

    /// 화면·상태별로 저장소 구성을 바꾼다 — 어떤 방이 들어 있는지, 응답이 늦는지, 실패하는지.
    private static func makeRepository(for screen: DemoScreen) -> InMemoryRoomRepository {
        switch screen {
        case let .list(state):
            switch state {
            case .default: return make(rooms: RoomSamples.mixed)
            case .shooting: return make(rooms: RoomSamples.shootingOnly)
            case .printed: return make(rooms: RoomSamples.completedOnly)
            case .empty: return make(rooms: [])
            // 응답이 오지 않게 두어 로딩 화면에 머문다.
            case .loading: return make(rooms: RoomSamples.mixed, latency: .seconds(600))
            case .error: return make(rooms: RoomSamples.mixed, failure: .network)
            }

        // 메뉴·드로어는 목록 위에 겹쳐 뜨므로 뒤에 깔리는 목록은 기본 구성으로 둔다.
        case .menu, .create, .join:
            return make(rooms: RoomSamples.mixed)
        }
    }

    private static func make(
        rooms: [Room],
        latency: Duration = .zero,
        failure: RoomError? = nil
    ) -> InMemoryRoomRepository {
        InMemoryRoomRepository(
            rooms: rooms,
            inviteCodes: RoomSamples.inviteCodes,
            latency: latency,
            failure: failure
        )
    }
}
