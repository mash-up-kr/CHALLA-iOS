import ComposableArchitecture
import RoomDomain

/// 초대 코드 입장 드로어의 TCA Feature.
///
/// 코드를 입력받아 방에 입장한다. 입장 성공은 `delegate(.joined)`로 부모(홈)에 알리고,
/// 드로어를 닫을지는 부모가 정한다. 실패 얼럿은 이 리듀서가 소유한다 —
/// 코드를 잘못 친 경우가 흔해 드로어를 연 채 고쳐 칠 수 있어야 한다.
@Reducer
public struct JoinRoomFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var code = ""
        public var isJoining = false
        @Presents public var alert: AlertState<Action.Alert>?

        /// "입장하기" 버튼 활성 조건. 요청 중이거나 공백만 입력한 코드면 잠근다.
        public var canSubmit: Bool { !isJoining && InviteCodeRule.isSubmittable(code) }

        public init() {}
    }

    // MARK: - Action

    public enum Action: BindableAction, ViewAction, Sendable {

        /// UI에서만 트리거되는 액션 (`@ViewAction` 뷰가 `send(...)`로 호출).
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
        // 코드 정규화는 제출 시점에 UseCase가 한 번 한다.
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .view(.closeButtonTapped):
                return .run { [dismiss] _ in await dismiss() } // 비-Sendable self 대신 의존성 값만 캡처

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
        return .run { [joinRoomUseCase] send in // 비-Sendable self 대신 의존성 값만 캡처
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
