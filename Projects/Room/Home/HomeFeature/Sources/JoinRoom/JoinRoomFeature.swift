import ComposableArchitecture
import RoomDomain

/// 초대 코드 입장 드로어. 성공은 `delegate(.joined)`로 홈에 알리고, 닫는 것은 홈이 정한다.
/// 실패 얼럿은 이 리듀서의 State에 둔다 — 드로어를 연 채 코드를 고쳐 다시 시도할 수 있어야 한다.
@Reducer
public struct JoinRoomFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var code = ""
        public var isJoining = false
        @Presents public var alert: AlertState<Action.Alert>?

        /// "입장하기" 버튼 활성 조건. 요청 중이거나 공백만 입력한 코드면 비활성화 한다.
        public var canSubmit: Bool {
            !isJoining && InviteCodeRule.isSubmittable(code)
        }

        public init() {}
    }

    // MARK: - Action

    public enum Action: BindableAction, ViewAction, Sendable {

        /// 뷰가 `send(...)`로 보내는 액션 (`@ViewAction`).
        public enum ViewAction: Sendable {
            case closeButtonTapped
            case joinButtonTapped
        }

        case view(ViewAction)

        /// 초대 코드 텍스트필드 입력.
        case binding(BindingAction<State>)

        /// parent(홈)에게만 알린다. 목록 반영과 드로어 닫기는 홈이 한다.
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case joined(Room)
        }

        case delegate(Delegate)

        case joinResponse(Result<Room, RoomError>)

        public enum Alert: Equatable, Sendable {}

        case alert(PresentationAction<Alert>)
    }

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.joinRoomUseCase) var joinRoomUseCase
    @Dependency(\.dismiss) var dismiss

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        // 방 만들기와 달리 입력을 즉시 다듬지 않는다 — 타이핑 중에 공백을 지우면 커서가 튄다.
        // 앞뒤 공백 제거는 제출 시점에 UseCase가 한다.
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .view(.closeButtonTapped):
                return .run { [dismiss] _ in await dismiss() }

            case .view(.joinButtonTapped):
                return joinRoom(&state)

            case let .joinResponse(.success(room)):
                state.isJoining = false
                return .send(.delegate(.joined(room)))

            case let .joinResponse(.failure(error)):
                state.isJoining = false
                // TODO: 얼럿 제목·버튼 문구는 임의 작성본 — 기획 정책 확정 시 교체할 것.
                state.alert = AlertState {
                    TextState("방에 입장하지 못했어요")
                } actions: {
                    ButtonState(role: .cancel) { TextState("확인") }
                } message: {
                    TextState(error.userMessage)
                }
                return .none

            case .binding, .delegate, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    // MARK: - Effects

    private enum CancelID {
        case join
    }

    private func joinRoom(_ state: inout State) -> Effect<Action> {
        guard state.canSubmit else { return .none }
        state.isJoining = true
        let code = state.code
        return .run { [joinRoomUseCase] send in
            do {
                let room = try await joinRoomUseCase.run(code)
                await send(.joinResponse(.success(room)))
            } catch let error as RoomError {
                await send(.joinResponse(.failure(error)))
            } catch is CancellationError {
                // 드로어 닫힘 등으로 취소 — 무시
            } catch {
                await send(.joinResponse(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.join, cancelInFlight: true)
    }
}
