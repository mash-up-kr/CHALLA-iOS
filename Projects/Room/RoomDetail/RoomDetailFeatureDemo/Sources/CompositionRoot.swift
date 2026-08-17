import ComposableArchitecture
import PhotoDomain
import RoomData // 앱 조립 지점이라 Data를 직접 import 한다 (아키텍처 규칙 2의 예외)
import RoomDomain

/// 의존성 조립 지점 — 데모앱에서 유일하게 Data 구현체를 만드는 곳.
///
/// 방 조회는 `InMemoryRoomRepository`를 쓴다. 사진 조회는 아직 Data 구현(PhotoData)이 없어
/// 여기서 값을 직접 만들어 넣는다 — 구현이 생기면 이 자리만 바꾸고 Feature는 손대지 않는다.
enum CompositionRoot {

    static func registerDependencies(for screen: DemoScreen, into values: inout DependencyValues) {
        guard case let .detail(state) = screen else { return }

        let room = DemoSamples.room(for: state)
        let repository = InMemoryRoomRepository(
            cards: [RoomCard(room: room, memberCount: DemoSamples.members.count, thumbnailURLs: [])],
            inviteCodes: [DemoSamples.inviteCode: room.id],
            membersByRoom: [room.id: DemoSamples.members],
            // 실패를 심으면 상세·참여자 조회가 모두 던진다. 사진은 별개라 그대로 온다.
            failure: state == .error ? .network : nil
        )

        values.fetchRoomDetailUseCase = .live(repository: repository)
        values.fetchRoomPhotosUseCase = FetchRoomPhotosUseCase(run: { _ in
            DemoSamples.photos(count: DemoSamples.photoCount(for: state))
        })
        // 복사는 실제 클립보드에 쓴다 — 데모에서 붙여넣기까지 확인할 수 있다.
    }
}
