import ComposableArchitecture
import RoomDomain

/// 방 이름 수정 드로어. 성공은 `delegate(.renamed)`로 방 설정에 알리고, 닫는 것은 방 설정이 정한다.
/// 실패 얼럿은 이 리듀서의 State에 둔다 — 드로어를 연 채 입력값 그대로 다시 시도할 수 있어야 한다.
/// (방 만들기 드로어와 같은 구조 — 입력이 이름 하나뿐이고 제출이 변경 요청인 점만 다르다.)
@Reducer
public struct RenameRoomFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public let roomID: Room.ID
        /// 비교 기준이 되는 현재 이름. 그대로면 제출할 이유가 없어 버튼을 잠근다.
        public let originalTitle: String
        public var name: String
        public var isSubmitting = false
        @Presents public var alert: AlertState<Action.Alert>?

        /// "변경" 버튼 활성 조건 — 요청 중이 아니고, 규칙에 맞는 이름이며, 실제로 달라졌을 때.
        public var canSubmit: Bool {
            !isSubmitting && RoomNameRule.isSubmittable(name) && name != originalTitle
        }

        public init(roomID: Room.ID, title: String) {
            self.roomID = roomID
            self.originalTitle = title
            self.name = title // 현재 이름을 미리 채워 고쳐 쓰는 자리임을 보여준다 (시안)
        }
    }

    // MARK: - Action

    public enum Action: BindableAction, ViewAction, Sendable {

        /// 뷰가 `send(...)`로 보내는 액션 (`@ViewAction`).
        public enum ViewAction: Sendable {
            case closeButtonTapped
            case submitButtonTapped
        }

        case view(ViewAction)

        /// 방 이름 텍스트필드 입력.
        case binding(BindingAction<State>)

        /// 부모(방 설정)에게만 알린다. 행 값 갱신과 드로어 닫기는 방 설정이 한다.
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            /// 서버에 저장된 정제 후 이름 — 화면 갱신은 입력값이 아니라 이 값으로 한다.
            case renamed(String)
        }

        case delegate(Delegate)

        case renameResponse(Result<String, RoomError>)

        public enum Alert: Equatable, Sendable {}

        case alert(PresentationAction<Alert>)
    }

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.updateRoomTitleUseCase) var updateRoomTitleUseCase
    @Dependency(\.dismiss) var dismiss

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            // BindingReducer가 입력값을 먼저 쓰고, 여기서 20자로 잘라 되쓴다 (방 만들기와 동일).
            case .binding(\.name):
                state.name = RoomNameRule.truncated(state.name)
                return .none

            case .view(.closeButtonTapped):
                return .run { [dismiss] _ in await dismiss() }

            case .view(.submitButtonTapped):
                return rename(&state)

            case let .renameResponse(.success(name)):
                state.isSubmitting = false
                return .send(.delegate(.renamed(name)))

            case let .renameResponse(.failure(error)):
                state.isSubmitting = false
                // TODO: 얼럿 제목·버튼 문구는 임의 작성본 — 기획 정책 확정 시 교체할 것.
                state.alert = AlertState {
                    TextState("방 이름을 바꾸지 못했어요")
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
        case rename
    }

    private func rename(_ state: inout State) -> Effect<Action> {
        guard state.canSubmit else { return .none }
        state.isSubmitting = true
        return .run { [updateRoomTitleUseCase, roomID = state.roomID, name = state.name] send in
            do {
                let saved = try await updateRoomTitleUseCase.run(roomID, name)
                await send(.renameResponse(.success(saved)))
            } catch let error as RoomError {
                await send(.renameResponse(.failure(error)))
            } catch is CancellationError {
                // 드로어 닫힘 등으로 취소 — 무시
            } catch {
                await send(.renameResponse(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.rename, cancelInFlight: true)
    }
}
