import ComposableArchitecture
import RoomDetailFeature

/// `DemoScreen` 하나를 띄울 수 있는 스토어로 바꾼다.
///
/// 화면 상태(팝오버가 열려 있는지)는 여기서 State에 심고,
/// 데이터 구성은 `CompositionRoot`가 의존성으로 넣는다.
enum DemoStore {

    static func make(for screen: DemoScreen) -> StoreOf<RoomDetailFeature> {
        Store(initialState: initialState(for: screen)) {
            RoomDetailFeature()._printChanges()
        } withDependencies: {
            CompositionRoot.registerDependencies(for: screen, into: &$0)
        }
    }

    private static func initialState(for screen: DemoScreen) -> RoomDetailFeature.State {
        guard case let .detail(state) = screen else {
            return RoomDetailFeature.State(room: DemoSamples.room(for: .shooting))
        }

        var initial = RoomDetailFeature.State(room: DemoSamples.room(for: state))
        // 팝오버는 참여자 바를 탭해야 열린다 — 진입 조회가 참여자를 채우면 열린 채로 보인다.
        initial.isInvitePopoverPresented = state == .invite
        return initial
    }
}
