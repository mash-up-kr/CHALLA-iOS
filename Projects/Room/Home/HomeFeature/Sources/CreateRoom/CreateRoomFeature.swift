import ComposableArchitecture
import RoomDomain

/// 방 만들기 드로어의 TCA Feature.
///
/// 이름을 입력받고 촬영 매수를 골라 방을 만든다. 생성 성공은 `delegate(.created)`로
/// 부모(홈)에 알리고, 드로어를 닫을지는 부모가 정한다. 실패 얼럿은 이 리듀서가 소유한다 —
/// 드로어를 열어 둔 채 입력값 그대로 다시 시도할 수 있어야 해서다.
@Reducer
public struct CreateRoomFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var name = ""
        public var shotCount: RoomShotCount = .default
        public var isCreating = false
        @Presents public var alert: AlertState<Action.Alert>?

        /// "만들기" 버튼 활성 조건. 요청 중이거나 공백만 입력한 이름이면 잠근다.
        public var canSubmit: Bool { !isCreating && RoomNameRule.isSubmittable(name) }

        public init() {}
    }

    // MARK: - Action

    public enum Action: BindableAction, ViewAction, Sendable {

        /// UI에서만 트리거되는 액션 (`@ViewAction` 뷰가 `send(...)`로 호출).
        public enum ViewAction: Sendable {
            case closeButtonTapped
            case shotCountSelected(RoomShotCount)
            case createButtonTapped
        }

        case view(ViewAction)

        /// 방 이름 텍스트필드 입력.
        case binding(BindingAction<State>)

        /// parent(홈)에게만 알린다. 목록 반영과 드로어 닫기는 홈이 한다.
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case created(Room)
        }

        case delegate(Delegate)

        case createResponse(Result<Room, RoomError>)

        public enum Alert: Equatable, Sendable {}

        case alert(PresentationAction<Alert>)
    }

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.createRoomUseCase) var createRoomUseCase
    @Dependency(\.dismiss) var dismiss

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            // BindingReducer가 입력값을 먼저 쓰고, 여기서 20자로 잘라 되쓴다.
            // 잘린 값이 텍스트필드에 다시 반영되어 21번째 글자가 화면에 남지 않는다.
            case .binding(\.name):
                state.name = RoomNameRule.sanitize(state.name)
                return .none

            case let .view(.shotCountSelected(count)):
                state.shotCount = count
                return .none

            case .view(.closeButtonTapped):
                return .run { [dismiss] _ in await dismiss() } // 비-Sendable self 대신 의존성 값만 캡처

            case .view(.createButtonTapped):
                return createRoom(&state)

            case let .createResponse(.success(room)):
                state.isCreating = false
                return .send(.delegate(.created(room)))

            case let .createResponse(.failure(error)):
                state.isCreating = false
                // TODO: 얼럿 제목·버튼 문구는 임의 작성본 — 기획 정책 확정 시 교체할 것.
                state.alert = AlertState {
                    TextState("방을 만들지 못했어요")
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
        case create
    }

    private func createRoom(_ state: inout State) -> Effect<Action> {
        guard state.canSubmit else { return .none }
        state.isCreating = true
        let draft = RoomDraft(name: state.name, shotCount: state.shotCount)
        return .run { [createRoomUseCase] send in // 비-Sendable self 대신 의존성 값만 캡처
            do {
                let room = try await createRoomUseCase.run(draft)
                await send(.createResponse(.success(room)))
            } catch let error as RoomError {
                await send(.createResponse(.failure(error)))
            } catch is CancellationError {
                // 드로어 닫힘 등으로 취소 — 무시
            } catch {
                await send(.createResponse(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.create, cancelInFlight: true)
    }
}
