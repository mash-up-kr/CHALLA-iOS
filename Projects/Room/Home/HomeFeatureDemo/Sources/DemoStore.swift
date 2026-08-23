import ComposableArchitecture
import HomeFeature
import RoomData

/// `DemoScreen` 하나를 띄울 수 있는 스토어로 바꾼다.
///
/// 화면 상태(드로어·메뉴가 열려 있는지)는 여기서 State에 심고,
/// 데이터 구성은 `CompositionRoot`가 의존성으로 넣는다.
enum DemoStore {

    /// 빈 상태 인사말에 쓰는 닉네임. 프로필 Domain이 아직 없어 부모가 넣어 주는 값이라
    /// 데모앱은 시안 문구를 그대로 쓴다.
    private static let nickname = "나는야멋쟁이토마토"

    static func make(for screen: DemoScreen) -> StoreOf<HomeFeature> {
        Store(initialState: initialState(for: screen)) {
            HomeFeature()._printChanges()
        } withDependencies: {
            CompositionRoot.registerDependencies(for: screen, into: &$0)
        }
    }

    private static func initialState(for screen: DemoScreen) -> HomeFeature.State {
        var state = HomeFeature.State(nickname: nickname)
        // 하단 "인화 완료" 목록이 처음부터 보이게 확인 기록을 미리 넣는다.
        state.checkedPrintedRoomIDs = RoomSamples.checkedPrintedRoomIDs
        switch screen {
        case .list:
            break
        case .menu:
            state.isPlusMenuPresented = true
        case let .create(drawer):
            state.destination = .createRoom(createRoomState(drawer))
        case let .join(drawer):
            state.destination = .joinRoom(joinRoomState(drawer))
        }
        return state
    }

    /// `filled`는 버튼이 활성인 컷을 보려고 이름을 미리 채운 것이다.
    private static func createRoomState(_ drawer: DemoScreen.DrawerState) -> CreateRoomFeature.State {
        var state = CreateRoomFeature.State()
        if drawer == .filled {
            state.name = "친구들과 강릉 여행"
        }
        return state
    }

    /// 채우는 값이 실제 초대 코드라, 그대로 "입장하기"를 누르면 강릉 방에 들어간다.
    private static func joinRoomState(_ drawer: DemoScreen.DrawerState) -> JoinRoomFeature.State {
        var state = JoinRoomFeature.State()
        if drawer == .filled {
            state.code = RoomSamples.inviteCode
        }
        return state
    }
}
