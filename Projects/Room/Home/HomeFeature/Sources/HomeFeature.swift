import ComposableArchitecture
import RoomDomain

/// 홈 화면의 TCA Feature.
///
/// 화면이 뜨면 방 목록을 한 번 가져오고, 그 결과 하나에서 촬영 중·촬영 완료 두 섹션이 파생된다.
/// 방 상세와 설정 화면은 다른 Feature 소관이라 `delegate`로 부모에게 넘긴다.
@Reducer
public struct HomeFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var rooms: IdentifiedArrayOf<Room> = []
        public var loadState: LoadState = .notRequested
        @Presents public var alert: AlertState<Action.Alert>?

        /// 섹션 분류는 Domain 규칙에 맡긴다. 저장하면 `rooms`와 어긋날 수 있어 매번 계산한다.
        public var board: RoomBoard { RoomBoard(rooms: rooms.elements) }

        public init() {}
    }

    /// 조회를 요청했는지, 받았는지로 갈리는 네 상태.
    ///
    /// 방이 정말 없는 것과 아직 못 받은 것을 구분하기 위해 둔다 — `rooms.isEmpty`만 보면
    /// 첫 조회 중에 빈 화면이 잠깐 보였다 사라진다.
    public enum LoadState: Equatable, Sendable {
        case notRequested
        case loading
        case loaded
        case failed(RoomError)
    }

    // MARK: - Action

    public enum Action: ViewAction, Sendable {

        /// UI에서만 트리거되는 액션 (`@ViewAction` 뷰가 `send(...)`로 호출).
        public enum ViewAction: Sendable {
            case task
            case retryButtonTapped
            /// 뷰가 들고 있던 값을 되돌려 보내면 낡은 값일 수 있어 id만 받는다.
            case roomTapped(Room.ID)
            case settingsButtonTapped
        }

        case view(ViewAction)

        /// parent(App)에게만 알린다. 화면 전환은 App이 조립한다.
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case roomSelected(Room)
            case settingsTapped
        }

        case delegate(Delegate)

        case roomsResponse(Result<[Room], RoomError>)

        public enum Alert: Equatable, Sendable {
            case retryTapped
        }

        case alert(PresentationAction<Alert>)
    }

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.fetchRoomsUseCase) var fetchRoomsUseCase

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // 화면 등장·재시도 버튼·얼럿의 다시 시도가 같은 조회를 부른다.
            case .view(.task), .view(.retryButtonTapped), .alert(.presented(.retryTapped)):
                return fetchRooms(&state)

            case let .roomsResponse(.success(rooms)):
                state.loadState = .loaded
                state.rooms = IdentifiedArray(uniqueElements: rooms)
                return .none

            case let .roomsResponse(.failure(error)):
                state.loadState = .failed(error)
                // 화면 본문은 직전 목록을 유지한다 — 재조회 실패로 보던 목록이 사라지지 않게.
                // TODO: 얼럿 제목·버튼 문구는 임의 작성본 — 기획 정책 확정 시 교체할 것.
                state.alert = AlertState {
                    TextState("방 목록을 불러오지 못했어요")
                } actions: {
                    ButtonState(action: .retryTapped) { TextState("다시 시도") }
                    ButtonState(role: .cancel) { TextState("확인") }
                } message: {
                    TextState(error.userMessage)
                }
                return .none

            case let .view(.roomTapped(id)):
                guard let room = state.rooms[id: id] else { return .none }
                return .send(.delegate(.roomSelected(room)))

            case .view(.settingsButtonTapped):
                return .send(.delegate(.settingsTapped))

            case .delegate, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    // MARK: - Effects

    private enum CancelID {
        case fetchRooms
    }

    private func fetchRooms(_ state: inout State) -> Effect<Action> {
        guard state.loadState != .loading else { return .none }
        state.loadState = .loading
        return .run { [fetchRoomsUseCase] send in // 비-Sendable self 대신 의존성 값만 캡처
            do {
                let rooms = try await fetchRoomsUseCase.run()
                await send(.roomsResponse(.success(rooms)))
            } catch let error as RoomError {
                await send(.roomsResponse(.failure(error)))
            } catch is CancellationError {
                // 이펙트 취소(예: 화면 이탈) — 무시
            } catch {
                await send(.roomsResponse(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.fetchRooms, cancelInFlight: true)
    }
}
