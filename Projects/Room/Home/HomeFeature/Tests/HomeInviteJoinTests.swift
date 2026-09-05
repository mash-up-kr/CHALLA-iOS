@testable import HomeFeature
import ComposableArchitecture
import RoomDomain
import Testing

/// 초대 링크 코드를 App에게 받았을 때 홈이 하는 일 — 입장·목록 반영·delegate, 실패 얼럿.
@MainActor
@Suite("HomeFeature 초대 링크 입장")
struct HomeInviteJoinTests {

    private static func makeStore(
        cards: [RoomCard] = [],
        join: JoinRoomUseCase = .testValue // 기본값이 미구현 — 불리면 안 되는 테스트가 그대로 쓴다
    ) -> TestStoreOf<HomeFeature> {
        var state = HomeFeature.State(nickname: "찰나")
        state.cards = IdentifiedArray(uniqueElements: cards)
        return TestStore(initialState: state) {
            HomeFeature()
        } withDependencies: {
            $0.joinRoomUseCase = join
        }
    }

    @Test("코드를 받으면 입장하고 목록 맨 앞에 꽂은 뒤 방 상세를 요청한다")
    func joinsAndDelegates() async {
        let store = Self.makeStore(
            cards: [.previewPrinted],
            join: JoinRoomUseCase(run: { _ in .previewShooting })
        )

        await store.send(.inviteCodeReceived("1928121"))
        await store.receive(\.inviteJoinResponse.success) {
            $0.cards = [.previewShooting, .previewPrinted]
        }
        await store.receive(\.delegate.roomJoined, .previewShooting)
    }

    @Test("이미 들어간 방의 링크면 중복 없이 값만 갱신한다")
    func rejoinUpdatesInPlace() async {
        let updated = RoomCard(room: .previewShooting, memberCount: 99, thumbnailURLs: [])
        let store = Self.makeStore(
            cards: [.previewShooting],
            join: JoinRoomUseCase(run: { _ in updated })
        )

        await store.send(.inviteCodeReceived("1928121"))
        await store.receive(\.inviteJoinResponse.success) {
            $0.cards = [updated]
        }
        await store.receive(\.delegate.roomJoined, updated)
    }

    @Test("입장에 실패하면 얼럿으로 알린다")
    func failureShowsAlert() async {
        let store = Self.makeStore(
            join: JoinRoomUseCase(run: { _ in throw RoomError.roomNotFound })
        )

        await store.send(.inviteCodeReceived("0000000"))
        await store.receive(\.inviteJoinResponse.failure) {
            $0.destination = .alert(AlertState {
                TextState("초대 링크로 입장하지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(RoomError.roomNotFound.userMessage)
            })
        }
    }

    @Test("드로어가 떠 있으면 얼럿으로 덮지 않는다")
    func drawerKeepsFocus() async {
        var state = HomeFeature.State(nickname: "찰나")
        state.destination = .joinRoom(JoinRoomFeature.State())
        let store = TestStore(initialState: state) {
            HomeFeature()
        } withDependencies: {
            $0.joinRoomUseCase = JoinRoomUseCase(run: { _ in throw RoomError.roomNotFound })
        }

        await store.send(.inviteCodeReceived("0000000"))
        await store.receive(\.inviteJoinResponse.failure) // 드로어 유지 — 상태 변화 없음
    }
}
