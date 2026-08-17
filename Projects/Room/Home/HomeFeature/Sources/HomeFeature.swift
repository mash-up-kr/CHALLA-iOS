import ComposableArchitecture
import Foundation
import PhotoDomain
import RoomDomain

/// 홈 화면. 방 목록을 한 번 가져와 촬영 중·촬영 완료 두 섹션으로 나눠 보여준다.
/// 방이 없으면 빈 상태를 그리고, 방 상세·설정으로 가는 것은 `delegate`로 App에 넘긴다.
@Reducer
public struct HomeFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        /// 빈 상태 인사말에 쓴다. 사용자 정보 Domain이 아직 없어 부모가 넣어 준다.
        /// TODO: 이슈 #33이 프로필을 만들면 UseCase 주입으로 바꾼다.
        public let nickname: String
        public let profileImageURL: URL?

        public var cards: IdentifiedArrayOf<RoomCard> = []
        public var loadState: LoadState = .notRequested

        /// 촬영 화면에 들어갈 준비(목록 조회·권한 요청) 중인 방. 그 카드의 뱃지가 스피너로 바뀐다.
        public var preparingShootRoomID: Room.ID?

        /// 상단 + 드롭다운의 열림 여부 (Destination에 넣지 않은 이유는 아래).
        public var isPlusMenuPresented = false
        @Presents public var destination: Destination.State?

        /// 섹션 분류는 Domain 규칙에 맡긴다. 저장하면 `cards`와 어긋날 수 있어 매번 계산한다.
        public var board: RoomBoard {
            RoomBoard(cards: cards.elements)
        }

        /// 첫 조회 중에만 참이다. 재조회 중에는 거짓이라 보던 목록이 스피너로 바뀌지 않는다.
        public var showsLoading: Bool {
            loadState == .loading && cards.isEmpty
        }

        /// 조회를 마쳤는데 방이 0개일 때만 참이다.
        /// 아직 못 받은 것과 구분해야 진입 직후에 빈 상태가 잠깐 보였다 사라지지 않는다.
        public var showsEmptyState: Bool {
            loadState == .loaded && board.isEmpty
        }

        /// 조회에 실패했고 보여줄 목록도 없을 때의 안내 문구. 그 외에는 nil.
        /// 재조회 실패는 직전 목록을 그대로 두므로 여기 해당하지 않는다.
        public var errorMessage: String? {
            guard case let .failed(error) = loadState, cards.isEmpty else { return nil }
            return error.userMessage
        }

        public init(nickname: String, profileImageURL: URL? = nil) {
            self.nickname = nickname
            self.profileImageURL = profileImageURL
        }
    }

    /// 방이 정말 없는 것과 아직 못 받은 것을 구분한다 — `cards.isEmpty`만 보면
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
        case joinRoom(JoinRoomFeature)
        case alert(AlertState<HomeFeature.Action.Alert>)
    }

    // MARK: - Action

    public enum Action: ViewAction, Sendable {

        /// 뷰가 `send(...)`로 보내는 액션 (`@ViewAction`).
        public enum ViewAction: Sendable {
            case task
            case retryButtonTapped
            /// `RoomCard` 대신 id를 받는다 — 뷰가 그린 값과 State의 값이 다를 수 있어 리듀서가 State에서 찾는다.
            case roomTapped(Room.ID)
            /// 카드 하단 촬영 뱃지. 목록·권한을 받아 두고 성공하면 카메라로 넘어간다.
            case shootButtonTapped(Room.ID)
            case settingsButtonTapped
            case plusButtonTapped
            case plusMenuDismissed

            // 아래 둘은 진입점이 두 곳이다 — 빈 상태의 버튼과 + 메뉴.
            case createRoomButtonTapped
            case joinRoomButtonTapped

            /// 드로어를 딤 탭이나 끌어내려서 닫았을 때 온다.
            /// 지금 두 드로어는 그 방식을 막아 뒀고(`allowsInteractiveDismiss: false`) X 버튼으로만 닫힌다.
            case drawerDismissed
        }

        case view(ViewAction)

        /// 부모(App)에게만 알린다. 화면 전환은 App이 조립한다.
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case roomSelected(RoomCard)
            case roomCreated(RoomCard)
            case roomJoined(RoomCard)
            case settingsTapped
            /// 촬영 준비가 끝났다 — 목록·권한이 모두 갖춰졌으니 카메라 화면을 띄우면 된다.
            case cameraRequested(CameraEntry)
        }

        case delegate(Delegate)

        case roomsResponse(Result<[RoomCard], RoomError>)
        case shootPreparationResponse(Result<CameraEntry, ShootPreparationError>)

        public enum Alert: Equatable, Sendable {
            case retryTapped
            case openCameraSettingsTapped
        }

        case destination(PresentationAction<Destination.Action>)
    }

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.fetchRoomsUseCase) var fetchRoomsUseCase
    @Dependency(\.fetchShootableRoomsUseCase) var fetchShootableRoomsUseCase
    @Dependency(\.fetchCameraFiltersUseCase) var fetchCameraFiltersUseCase
    @Dependency(\.requestCameraPermissionUseCase) var requestCameraPermissionUseCase
    @Dependency(\.openCameraSettingsUseCase) var openCameraSettingsUseCase

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.task), .view(.retryButtonTapped),
                 .destination(.presented(.alert(.retryTapped))):
                // 화면 등장·재시도 버튼·얼럿의 다시 시도가 같은 조회를 부른다.
                return fetchRooms(&state)

            case let .roomsResponse(.success(cards)):
                state.loadState = .loaded
                state.cards = IdentifiedArray(uniqueElements: cards)
                return .none

            case let .roomsResponse(.failure(error)):
                state.loadState = .failed(error)

                // 드로어가 떠 있으면 얼럿으로 덮지 않는다 — Destination이 enum이라 입력 중이던 값이 함께 사라진다.
                // 실패는 loadState에 남아 드로어를 닫으면 본문이 알린다.
                guard state.destination == nil else { return .none }

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

            case let .view(.roomTapped(id)):
                guard let card = state.cards[id: id] else { return .none }
                return .send(.delegate(.roomSelected(card)))

            // MARK: 촬영 진입

            case let .view(.shootButtonTapped(roomID)):
                // 준비 중에 다른 카드를 누르면 앞의 준비는 버리고 새로 시작한다 (cancelInFlight).
                guard state.cards[id: roomID] != nil else { return .none }
                state.preparingShootRoomID = roomID
                return prepareShoot(roomID: roomID)

            case let .shootPreparationResponse(.success(entry)):
                state.preparingShootRoomID = nil
                return .send(.delegate(.cameraRequested(entry)))

            case let .shootPreparationResponse(.failure(error)):
                state.preparingShootRoomID = nil
                state.destination = .alert(error.alert)
                return .none

            case .destination(.presented(.alert(.openCameraSettingsTapped))):
                return .run { [openCameraSettingsUseCase] _ in
                    await openCameraSettingsUseCase.run()
                }

            case .view(.settingsButtonTapped):
                return .send(.delegate(.settingsTapped))

            // MARK: + 메뉴 · 드로어

            case .view(.plusButtonTapped):
                state.isPlusMenuPresented.toggle()
                return .none

            case .view(.plusMenuDismissed):
                state.isPlusMenuPresented = false
                return .none

            // + 메뉴에서 들어왔을 수 있어 드로어를 열기 전에 메뉴를 내린다.
            case .view(.createRoomButtonTapped):
                state.isPlusMenuPresented = false
                state.destination = .createRoom(CreateRoomFeature.State())
                return .none

            case .view(.joinRoomButtonTapped):
                state.isPlusMenuPresented = false
                state.destination = .joinRoom(JoinRoomFeature.State())
                return .none

            case .view(.drawerDismissed):
                state.destination = nil
                return .none

            case let .destination(.presented(.createRoom(.delegate(.created(card))))):
                state.destination = nil
                state.cards.insert(card, at: 0)
                return .send(.delegate(.roomCreated(card)))

            // 초대 코드는 방에 계속 붙어 있어 이미 들어간 방에 다시 입장할 수 있다.
            // insert면 같은 id가 두 번 들어가므로 updateOrInsert를 쓴다 — at: 0은 새 방에만 적용된다.
            // TODO: 서버가 중복 입장에 성공을 주는지 에러를 주는지 미확정 — 에러면 이 처리는 얼럿으로 옮긴다.
            case let .destination(.presented(.joinRoom(.delegate(.joined(card))))):
                state.destination = nil
                state.cards.updateOrInsert(card, at: 0)
                return .send(.delegate(.roomJoined(card)))

            // delegate는 부모가 받고, 나머지 destination 액션은 ifLet이 자식에게 넘긴다.
            case .delegate, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    // MARK: - Effects

    private enum CancelID {
        case fetchRooms
        case prepareShoot
    }

    /// 촬영에 필요한 세 가지를 한꺼번에 받는다 — 방 목록·필터 목록·카메라 권한.
    /// 권한 창이 뜨는 동안에도 조회는 계속 나가므로, 사용자가 허용을 누를 때쯤이면 목록이 이미 와 있다.
    ///
    /// 셋 중 하나라도 어긋나면 카메라로 넘어가지 않는다 — 반쪽짜리 화면을 띄우지 않기 위해서다.
    /// 권한 거절을 조회 실패보다 먼저 보는 이유: 조회가 실패해도 사용자가 먼저 할 일은 권한 허용이다.
    private func prepareShoot(roomID: Room.ID) -> Effect<Action> {
        .run { [fetchShootableRoomsUseCase, fetchCameraFiltersUseCase, requestCameraPermissionUseCase] send in
            async let isPermitted = requestCameraPermissionUseCase.run()
            async let rooms = fetchShootableRoomsUseCase.run()
            async let filters = fetchCameraFiltersUseCase.run()

            do {
                let entry = try await CameraEntry(roomID: roomID, rooms: rooms, filters: filters)
                guard await isPermitted else {
                    await send(.shootPreparationResponse(.failure(.cameraPermissionDenied)))
                    return
                }
                await send(.shootPreparationResponse(.success(entry)))
            } catch is CancellationError {
            } catch {
                guard await isPermitted else {
                    await send(.shootPreparationResponse(.failure(.cameraPermissionDenied)))
                    return
                }
                await send(.shootPreparationResponse(.failure(.loadFailed(message: error.entryMessage))))
            }
        }
        .cancellable(id: CancelID.prepareShoot, cancelInFlight: true)
    }

    private func fetchRooms(_ state: inout State) -> Effect<Action> {
        state.loadState = .loading
        return .run { [fetchRoomsUseCase] send in // 비-Sendable self 대신 의존성 값만 캡처
            do {
                let cards = try await fetchRoomsUseCase.run()
                await send(.roomsResponse(.success(cards)))
            } catch let error as RoomError {
                await send(.roomsResponse(.failure(error)))
            } catch is CancellationError {
                // 이펙트 취소(예: 화면 이탈) — 무시
            } catch {
                await send(.roomsResponse(.failure(.unknown)))
            }
        }
        // 중복 요청은 cancelInFlight가 받는다 — 진행 중이던 요청을 취소하고 새로 시작한다.
        //
        // loadState로 막지 않는 이유: 화면을 벗어나면 .task가 취소되는데, 취소는 액션을 보내지 않아
        // loadState가 .loading에 남는다. 가드가 있으면 다시 들어와도 조회가 막혀 스피너가 계속 돈다.
        .cancellable(id: CancelID.fetchRooms, cancelInFlight: true)
    }
}

// MARK: - Destination conformance

// 매크로가 만든 State·Action은 public 타입이라 Equatable·Sendable이 자동 추론되지 않는다.
// 매크로 인자로 합성하는 `@Reducer(state:action:)`는 폐기돼 extension으로 직접 선언한다.
extension HomeFeature.Destination.State: Equatable {}
extension HomeFeature.Destination.Action: Sendable {}
