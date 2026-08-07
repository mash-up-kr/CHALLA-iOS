import ComposableArchitecture
import Foundation
import RoomDomain

/// 홈 화면의 TCA Feature.
///
/// 화면이 뜨면 방 목록을 한 번 가져오고, 그 결과 하나에서 촬영 중·촬영 완료 두 섹션이 파생된다.
/// 방이 하나도 없으면 목록 대신 빈 상태를 그린다.
/// 방 상세와 설정 화면은 다른 Feature 소관이라 `delegate`로 부모에게 넘긴다.
@Reducer
public struct HomeFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        /// 빈 상태 인사말에 쓰는 값들. 사용자 정보를 다루는 Domain이 아직 없어
        /// 부모(App·데모앱)가 넣어 준다. 이슈 #33이 프로필 정본을 만들면 UseCase 주입으로 바꾼다.
        public let nickname: String
        public let profileImageURL: URL?

        public var rooms: IdentifiedArrayOf<Room> = []
        public var loadState: LoadState = .notRequested

        /// 상단 + 드롭다운의 열림 여부. 여닫기만 하면 되어 Destination에 넣지 않았다 (아래 Destination 주석 참고).
        public var isPlusMenuPresented = false
        @Presents public var destination: Destination.State?

        /// 섹션 분류는 Domain 규칙에 맡긴다. 저장하면 `rooms`와 어긋날 수 있어 매번 계산한다.
        public var board: RoomBoard { RoomBoard(rooms: rooms.elements) }

        /// 조회를 마쳤는데 방이 없을 때만 참이다.
        /// 첫 조회 중에는 거짓이라 빈 상태가 잠깐 보였다 목록으로 바뀌는 일이 없다.
        public var showsEmptyState: Bool { loadState == .loaded && board.isEmpty }

        public init(nickname: String, profileImageURL: URL? = nil) {
            self.nickname = nickname
            self.profileImageURL = profileImageURL
        }
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

    // MARK: - Destination

    /// 홈 위에 겹쳐 뜨는 것들. 드로어와 얼럿은 동시에 뜰 수 없어 enum 하나로 묶는다 —
    /// 옵셔널 둘로 두면 둘 다 떠 있는 상태를 코드로 만들 수 있지만 enum은 타입이 막는다.
    ///
    /// 상단 + 메뉴는 여기 없다 — 자식 리듀서도, 닫힐 때 취소할 이펙트도 없어
    /// `@Presents`가 해줄 일이 없기 때문이다 (`isPlusMenuPresented` Bool로 충분).
    @Reducer
    public enum Destination {
        case createRoom(CreateRoomFeature)
        case alert(AlertState<HomeFeature.Action.Alert>)
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
            case plusButtonTapped
            case plusMenuDismissed
            /// 빈 상태의 "방 만들기" 버튼과 + 메뉴의 "방 만들기"가 함께 쓴다.
            case createRoomButtonTapped
        }

        case view(ViewAction)

        /// parent(App)에게만 알린다. 화면 전환은 App이 조립한다.
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case roomSelected(Room)
            case roomCreated(Room)
            case settingsTapped
        }

        case delegate(Delegate)

        case roomsResponse(Result<[Room], RoomError>)

        public enum Alert: Equatable, Sendable {
            case retryTapped
        }

        case destination(PresentationAction<Destination.Action>)
    }

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.fetchRoomsUseCase) var fetchRoomsUseCase

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // 화면 등장·재시도 버튼·얼럿의 다시 시도가 같은 조회를 부른다.
            case .view(.task), .view(.retryButtonTapped),
                 .destination(.presented(.alert(.retryTapped))):
                return fetchRooms(&state)

            case let .roomsResponse(.success(rooms)):
                state.loadState = .loaded
                state.rooms = IdentifiedArray(uniqueElements: rooms)
                return .none

            case let .roomsResponse(.failure(error)):
                state.loadState = .failed(error)
                // 화면 본문은 직전 목록을 유지한다 — 재조회 실패로 보던 목록이 사라지지 않게.
                // TODO: 얼럿 제목·버튼 문구는 임의 작성본 — 기획 정책 확정 시 교체할 것.
                state.destination = .alert(AlertState {
                    TextState("방 목록을 불러오지 못했어요")
                } actions: {
                    ButtonState(action: .retryTapped) { TextState("다시 시도") }
                    ButtonState(role: .cancel) { TextState("확인") }
                } message: {
                    TextState(error.userMessage)
                })
                return .none

            // MARK: + 메뉴 · 방 만들기

            case .view(.plusButtonTapped):
                state.isPlusMenuPresented.toggle()
                return .none

            case .view(.plusMenuDismissed):
                state.isPlusMenuPresented = false
                return .none

            // 메뉴에서 진입했을 수 있어 드로어를 열기 전에 메뉴를 내린다.
            case .view(.createRoomButtonTapped):
                state.isPlusMenuPresented = false
                state.destination = .createRoom(CreateRoomFeature.State())
                return .none

            // 드로어를 닫고 목록 맨 앞에 반영한 뒤 부모(App)에 넘긴다.
            case let .destination(.presented(.createRoom(.delegate(.created(room))))):
                state.destination = nil
                state.rooms.insert(room, at: 0)
                return .send(.delegate(.roomCreated(room)))

            case let .view(.roomTapped(id)):
                guard let room = state.rooms[id: id] else { return .none }
                return .send(.delegate(.roomSelected(room)))

            case .view(.settingsButtonTapped):
                return .send(.delegate(.settingsTapped))

            case .delegate, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
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

// MARK: - Destination conformance

// 매크로가 만든 State·Action은 public 타입이라 Equatable·Sendable이 자동 추론되지 않는다.
// 매크로 인자로 합성하는 `@Reducer(state:action:)`는 폐기돼 extension으로 직접 선언한다.
extension HomeFeature.Destination.State: Equatable {}
extension HomeFeature.Destination.Action: Sendable {}
