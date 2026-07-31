import ComposableArchitecture
import SettingDomain

/// 설정 화면의 TCA Feature.
///
/// 화면 진입 시 프로필과 현재 테마를 한 번 불러와 보여주고,
/// 각 행을 누르면 어떤 화면으로 가야 하는지를 `delegate`로 알린다.
///
/// **이 화면은 설정 값을 바꾸지 않는다** — 테마 선택·알림·계정 관리는 전부 하위 화면의 몫이고
/// 하위 화면은 별도 이슈다. 그래서 여기엔 저장 액션이 없다.
@Reducer
public struct SettingFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {

        /// 아직 불러오지 못했으면 `nil` — 헤더와 테마 값 자리를 비워 둔다.
        public var snapshot: SettingsSnapshot?

        public var isLoading = false

        @Presents public var alert: AlertState<Action.Alert>?

        /// 테마 행에 표시할 값. 불러오기 전에는 `nil`이라 값 없이 화살표만 보인다.
        /// 빈 문자열을 넘기면 `CHALLAListRow`가 "값 있음"으로 보고 빈 Text와 간격을 그린다.
        public var themeDisplayName: String? {
            snapshot?.theme.displayName
        }

        public init() {}
    }

    // MARK: - Action

    public enum Action: ViewAction, Sendable {

        /// UI에서만 트리거되는 액션 (`@ViewAction` 뷰가 `send(...)`로 호출).
        public enum ViewAction: Sendable {
            case onAppear
            case editProfileButtonTapped
            case themeRowTapped
            case notificationRowTapped
            case accountRowTapped
            case supportRowTapped
            case feedbackRowTapped
            case backButtonTapped
        }

        case view(ViewAction)

        /// parent(App)에게만 알린다. 실제 화면 전환은 App이 조립한다 (아키텍처 규칙 3).
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case editProfileRequested
            case themeSelectionRequested
            case notificationSettingRequested
            case accountManagementRequested
            case supportRequested
            case feedbackRequested
            case backRequested
        }

        case delegate(Delegate)

        /// 내부 — 설정 불러오기 결과.
        case settingsResponse(Result<SettingsSnapshot, SettingError>)

        /// 얼럿 (확인 버튼만 — 추가 액션이 없어 빈 enum).
        public enum Alert: Equatable, Sendable {}
        case alert(PresentationAction<Alert>)
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.loadSettingsUseCase) var loadSettingsUseCase

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.onAppear):
                // 이미 불러왔으면 다시 부르지 않는다 — 하위 화면에서 돌아올 때마다 깜빡이지 않게.
                guard state.snapshot == nil, !state.isLoading else { return .none }
                state.isLoading = true
                return .run { [loadSettingsUseCase] send in // 비-Sendable self 대신 의존성 값만 캡처
                    await send(.settingsResponse(Result {
                        try await loadSettingsUseCase.run()
                    }.mapError()))
                }
                .cancellable(id: CancelID.load, cancelInFlight: true)

            case let .settingsResponse(.success(snapshot)):
                state.isLoading = false
                state.snapshot = snapshot
                return .none

            case let .settingsResponse(.failure(error)):
                state.isLoading = false
                // TODO: 얼럿 제목·버튼 문구는 임의 작성본 — 추후 기획 정책 확정 시 교체할 것.
                state.alert = AlertState {
                    TextState("설정을 불러오지 못했어요")
                } actions: {
                    ButtonState(role: .cancel) { TextState("확인") }
                } message: {
                    TextState(error.userMessage)
                }
                return .none

            case .view(.editProfileButtonTapped):
                return .send(.delegate(.editProfileRequested))

            case .view(.themeRowTapped):
                return .send(.delegate(.themeSelectionRequested))

            case .view(.notificationRowTapped):
                return .send(.delegate(.notificationSettingRequested))

            case .view(.accountRowTapped):
                return .send(.delegate(.accountManagementRequested))

            case .view(.supportRowTapped):
                return .send(.delegate(.supportRequested))

            case .view(.feedbackRowTapped):
                return .send(.delegate(.feedbackRequested))

            case .view(.backButtonTapped):
                return .send(.delegate(.backRequested))

            case .delegate, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    // MARK: - Effects

    private enum CancelID { case load }
}

// MARK: - Error normalization

private extension Result where Failure == any Error {

    /// UseCase의 라이브 구현이 실패를 전부 `SettingError`로 정규화하지만,
    /// 그러지 못한 오류가 새어 나올 경우를 대비해 `.unknown`으로 감싼다.
    func mapError() -> Result<Success, SettingError> {
        mapError { error in
            error as? SettingError ?? .unknown
        }
    }
}
