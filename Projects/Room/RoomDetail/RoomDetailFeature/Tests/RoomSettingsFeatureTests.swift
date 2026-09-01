@testable import RoomDetailFeature
import ComposableArchitecture
import RoomDomain
import Testing

@MainActor
@Suite("RoomSettingsFeature")
struct RoomSettingsFeatureTests {

    private nonisolated static let roomID = Room.previewShooting.id
    private nonisolated static let title = "제주 우정 여행"

    private static func makeStore() -> TestStoreOf<RoomSettingsFeature> {
        TestStore(initialState: RoomSettingsFeature.State(roomID: roomID, title: title)) {
            RoomSettingsFeature()
        }
    }

    // MARK: - 이름 수정 드로어

    @Test("방 이름 행을 탭하면 현재 방 id·이름으로 이름 수정 드로어가 열린다")
    func renameRowOpensDrawer() async {
        let store = Self.makeStore()

        await store.send(.view(.renameRowTapped)) {
            $0.rename = RenameRoomFeature.State(roomID: Self.roomID, title: Self.title)
        }
    }

    @Test("자식이 변경 완료를 알리면 행 값 갱신과 드로어 닫기가 한 번에 된다")
    func childRenamedUpdatesTitleAndClosesDrawer() async {
        let store = Self.makeStore()

        await store.send(.view(.renameRowTapped)) {
            $0.rename = RenameRoomFeature.State(roomID: Self.roomID, title: Self.title)
        }
        await store.send(.rename(.presented(.delegate(.renamed("강릉 여행"))))) {
            $0.title = "강릉 여행"
            $0.rename = nil
        }
    }

    @Test("드로어가 닫히면 이름 수정 State를 거둔다")
    func drawerDismissedClearsRename() async {
        let store = Self.makeStore()

        await store.send(.view(.renameRowTapped)) {
            $0.rename = RenameRoomFeature.State(roomID: Self.roomID, title: Self.title)
        }
        await store.send(.view(.drawerDismissed)) {
            $0.rename = nil
        }
    }

    // MARK: - 위임

    @Test("뒤로가기 버튼은 delegate로 위임한다")
    func backButtonDelegates() async {
        let store = Self.makeStore()

        await store.send(.view(.backButtonTapped))
        await store.receive(\.delegate.closeTapped)
    }

    @Test("커버 이미지 행은 delegate로 커버 수정을 요청한다")
    func coverRowDelegates() async {
        let store = Self.makeStore()

        await store.send(.view(.coverRowTapped))
        await store.receive(\.delegate.coverEditRequested)
    }
}
