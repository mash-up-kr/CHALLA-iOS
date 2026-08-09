import ComposableArchitecture
import SettingDomain

/// 계정 관리 화면의 TCA Feature.
///
/// 프로필 요약을 보여주고 로그아웃·회원 탈퇴를 처리한다.
/// 둘 다 되돌리기 어려워 확인 드로어를 한 번 거친다.
///
/// 실제 화면 전환(로그인 화면으로 리셋)은 하지 않는다 — `delegate`로 부모에 올리고 App이 조립한다.
@Reducer
public struct AccountFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {

        /// 설정 메인과 같은 프로필. 부모가 시드한다. `nil`이면 자리만 잡는다.
        public var profile: SettingProfile?

        /// 떠 있는 드로어. 한 번에 하나만 뜬다 —
        /// 모디파이어를 두 개 걸면 A를 내리는 애니메이션과 B를 올리는 애니메이션이 겹친다.
        public var drawer: Drawer?

        /// 로그아웃·탈퇴 진행 중. 중복 탭을 막는다.
        public var isProcessing = false

        @Presents public var alert: AlertState<Action.Alert>?

        /// 딤 탭·드래그로 드로어를 내릴 수 있는지.
        /// 완료 드로어는 이미 탈퇴가 끝나 그냥 닫히면 안 되고,
        /// 진행 중에 내리면 A가 사라졌다 B가 뜨며 화면이 한 번 빈다.
        public var isDrawerDismissable: Bool {
            drawer != .deleteCompleted && !isProcessing
        }

        public init(profile: SettingProfile?) {
            self.profile = profile
        }
    }

    /// 드로어 3종. 뷰가 이 값으로 `CHALLADrawer` 내용을 고른다.
    public enum Drawer: Equatable, Sendable {
        /// 로그아웃 확인. 시안에 없는 단계지만, 한 번의 오탭으로 세션이 끊기는 비용이 커서 넣었다.
        /// TODO: 문구 확정 필요 (제안: `로그아웃 할까요?` / 주 버튼 `로그아웃` / 보조 `닫기`).
        case signOutConfirmation
        /// 드로어 A — "모든 기록이 사라져요".
        case deleteConfirmation
        /// 드로어 B — "회원 탈퇴가 정상적으로 완료 됐어요".
        case deleteCompleted
    }

    // MARK: - Action

    public enum Action: ViewAction, Sendable {

        /// UI에서만 트리거되는 액션 (`@ViewAction` 뷰가 `send(...)`로 호출).
        public enum ViewAction: Sendable {
            case signOutRowTapped
            case deleteAccountButtonTapped
            case signOutConfirmed
            case deleteConfirmed
            case deleteCompletionConfirmed
            /// 드로어를 딤 탭·드래그·닫기 버튼으로 내렸다.
            case drawerDismissed
            case backButtonTapped
        }

        case view(ViewAction)

        // 내부 — `Result<Void, _>`는 `Void`가 `Equatable`이 아니라 상태 비교·테스트에서 걸린다.
        // 성공/실패를 액션 두 개로 나눈다.
        case signOutSucceeded
        case signOutFailed(SettingError)
        case accountDeletionSucceeded
        case accountDeletionFailed(SettingError)

        /// 부모에게만 알린다.
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            /// 로그아웃 완료. App이 로그인 화면으로 리셋한다.
            case signedOut
            /// 회원 탈퇴 완료. App이 로그인 화면으로 리셋한다.
            case accountDeleted
        }

        case delegate(Delegate)

        /// 얼럿 (확인 버튼만 — 추가 액션이 없어 빈 enum).
        public enum Alert: Equatable, Sendable {}
        case alert(PresentationAction<Alert>)
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.signOutUseCase) var signOutUseCase
    @Dependency(\.deleteAccountUseCase) var deleteAccountUseCase
    @Dependency(\.dismiss) var dismiss

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            // MARK: 로그아웃

            case .view(.signOutRowTapped):
                guard !state.isProcessing else { return .none }
                state.drawer = .signOutConfirmation
                return .none

            case .view(.signOutConfirmed):
                guard !state.isProcessing else { return .none }
                // 드로어를 그대로 두고 버튼만 잠근다 — 먼저 닫으면 응답이 올 때까지
                // 화면에 아무 변화가 없어 사용자가 눌렸는지 알 수 없다 (탈퇴와 같은 정책).
                state.isProcessing = true
                return .run { [signOutUseCase] send in
                    do {
                        try await signOutUseCase.run()
                        await send(.signOutSucceeded)
                    } catch {
                        await send(.signOutFailed(.normalized(error)))
                    }
                }
                .cancellable(id: CancelID.signOut)

            case .signOutSucceeded:
                state.isProcessing = false
                state.drawer = nil
                return .send(.delegate(.signedOut))

            case let .signOutFailed(error):
                state.isProcessing = false
                state.drawer = nil
                state.alert = Self.failureAlert(title: "로그아웃하지 못했어요", error: error)
                return .none

            // MARK: 회원 탈퇴

            case .view(.deleteAccountButtonTapped):
                guard !state.isProcessing else { return .none }
                state.drawer = .deleteConfirmation
                return .none

            case .view(.deleteConfirmed):
                guard !state.isProcessing else { return .none }
                // 드로어 A를 그대로 두고 주 버튼만 비활성으로 만든다 —
                // 먼저 닫고 나중에 B를 띄우면 중간에 아무 것도 없는 화면이 보인다.
                state.isProcessing = true
                return .run { [deleteAccountUseCase] send in
                    do {
                        try await deleteAccountUseCase.run()
                        await send(.accountDeletionSucceeded)
                    } catch {
                        await send(.accountDeletionFailed(.normalized(error)))
                    }
                }
                .cancellable(id: CancelID.delete)

            case .accountDeletionSucceeded:
                state.isProcessing = false
                state.drawer = .deleteCompleted
                return .none

            case let .accountDeletionFailed(error):
                state.isProcessing = false
                state.drawer = nil
                state.alert = Self.failureAlert(title: "탈퇴하지 못했어요", error: error)
                return .none

            case .view(.deleteCompletionConfirmed):
                state.drawer = nil
                return .send(.delegate(.accountDeleted))

            // MARK: 드로어 닫기

            case .view(.drawerDismissed):
                // 완료 드로어(B)는 `allowsInteractiveDismiss: false`로 띄우지만,
                // 새어 나오는 dismiss가 있으면 완료 확인과 같게 취급한다 —
                // 이미 탈퇴가 끝난 상태라 존재하지 않는 계정 화면에 남으면 안 된다.
                let wasCompleted = state.drawer == .deleteCompleted
                state.drawer = nil
                return wasCompleted ? .send(.delegate(.accountDeleted)) : .none

            case .view(.backButtonTapped):
                // 처리 중에 나가면 TCA가 이 화면의 이펙트를 취소해 성공도 실패도 오지 않는다.
                guard !state.isProcessing else { return .none }
                return .run { [dismiss] _ in await dismiss() }

            case .delegate, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    // MARK: - Alert

    // TODO: 얼럿 제목·버튼 문구는 임의 작성본 — 추후 기획 정책 확정 시 교체할 것.
    private static func failureAlert(title: String, error: SettingError) -> AlertState<Action.Alert> {
        AlertState {
            TextState(title)
        } actions: {
            ButtonState(role: .cancel) { TextState("확인") }
        } message: {
            TextState(error.userMessage)
        }
    }

    // MARK: - Effects

    private enum CancelID { case signOut, delete }
}
