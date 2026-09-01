import ComposableArchitecture
import RoomDetailFeature

/// `DemoScreen` 하나를 띄울 수 있는 스토어로 바꾼다.
///
/// 화면 상태(팝오버·드로어가 열려 있는지)는 여기서 State에 심고,
/// 데이터 구성은 `CompositionRoot`가 의존성으로 넣는다.
enum DemoStore {

    static func makeDetail(for state: DemoScreen.DetailState) -> StoreOf<RoomDetailFeature> {
        var initial = RoomDetailFeature.State(room: DemoSamples.room(for: state))
        // 팝오버는 참여자 바를 탭해야 열린다 — 진입 조회가 참여자를 채우면 열린 채로 보인다.
        initial.isInvitePopoverPresented = state == .invite
        return Store(initialState: initial) {
            RoomDetailFeature()._printChanges()
        } withDependencies: {
            CompositionRoot.registerDetailDependencies(for: state, into: &$0)
        }
    }

    static func makeSettings(for state: DemoScreen.SettingsState) -> StoreOf<RoomSettingsFeature> {
        let room = DemoSamples.room(for: .shooting)
        var initial = RoomSettingsFeature.State(roomID: room.id, title: room.title)
        // 드로어는 방 이름 행을 탭해야 열린다 — 검증용으로 열린 채 시작한다.
        if state == .rename {
            initial.rename = RenameRoomFeature.State(roomID: room.id, title: room.title)
        }
        return Store(initialState: initial) {
            RoomSettingsFeature()._printChanges()
        } withDependencies: {
            CompositionRoot.registerSettingsDependencies(room: room, into: &$0)
        }
    }
}
