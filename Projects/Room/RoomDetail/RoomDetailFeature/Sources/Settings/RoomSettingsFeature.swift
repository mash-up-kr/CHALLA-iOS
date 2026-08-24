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
        }

        case view(ViewAction)

        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case closeTapped
            /// 커버 수정 화면은 #69 작업 — App이 받아서 연결한다.
            case coverEditRequested
        }

        case delegate(Delegate)
    }

    public init() {}

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .view(.backButtonTapped):
                return .send(.delegate(.closeTapped))

            case .view(.renameRowTapped):
                // 이름 수정 드로어는 다음 걸음에서 연다.
                return .none

            case .view(.coverRowTapped):
                return .send(.delegate(.coverEditRequested))

            case .delegate:
                return .none
            }
        }
    }
}
