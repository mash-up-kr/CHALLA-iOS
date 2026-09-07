import ComposableArchitecture
import RoomDomain

/// 방 설정 화면. 방 이름·커버 이미지로 가는 진입 목록이다.
/// 화면 전환은 전부 `delegate`로 App에 알린다 (방 상세와 같은 방식).
@Reducer
public struct RoomSettingsFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public let roomID: Room.ID
        /// 방 이름 행의 값. 이름 수정이 성공하면 여기가 갱신된다.
        public var title: String
        /// 이름 수정 드로어. nil이면 닫혀 있다.
        @Presents public var rename: RenameRoomFeature.State?

        public init(roomID: Room.ID, title: String) {
            self.roomID = roomID
            self.title = title
        }
    }

    // MARK: - Action

    public enum Action: ViewAction, Sendable {

        public enum ViewAction: Sendable {
            case backButtonTapped
            case renameRowTapped
            case coverRowTapped
            /// 드로어를 딤 탭이나 끌어내려서 닫았을 때 온다.
            /// 지금은 그 방식을 막아 뒀고(`allowsInteractiveDismiss: false`) X 버튼으로만 닫힌다.
            case drawerDismissed
        }

        case view(ViewAction)

        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case closeTapped
            /// 커버 수정 화면은 #69 작업 — App이 받아서 연결한다.
            case coverEditRequested
        }

        case delegate(Delegate)

        case rename(PresentationAction<RenameRoomFeature.Action>)
    }

    public init() {}

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.backButtonTapped):
                return .send(.delegate(.closeTapped))

            case .view(.renameRowTapped):
                state.rename = RenameRoomFeature.State(roomID: state.roomID, title: state.title)
                return .none

            case .view(.coverRowTapped):
                return .send(.delegate(.coverEditRequested))

            case .view(.drawerDismissed):
                state.rename = nil
                return .none

            // 행 값을 서버에 저장된 이름으로 갱신하고 드로어를 닫는다.
            case let .rename(.presented(.delegate(.renamed(name)))):
                state.title = name
                state.rename = nil
                return .none

            // delegate는 부모가 받고, 나머지 rename 액션은 ifLet이 자식에게 넘긴다.
            case .delegate, .rename:
                return .none
            }
        }
        .ifLet(\.$rename, action: \.rename) {
            RenameRoomFeature()
        }
    }
}
