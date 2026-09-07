import ComposableArchitecture
import Foundation
import SettingDomain

/// 설정 화면의 TCA Feature.
///
/// 화면 진입 시 프로필(원격)을 불러와 보여주고,
/// 하위 화면(테마·알림·계정 관리)으로의 이동을 **직접** 관리한다 — `path`(`StackState`)를 소유한다.
///
/// 하위 화면이 같은 모듈 안에 있어 App이 조립할 것이 없다. App에 올리는 `delegate`는
/// 설정 밖으로 나가야 하는 것(프로필 편집·뒤로가기)과 앱 전체를 되돌려야 하는 것
/// (로그아웃·탈퇴 완료)뿐이다.
///
/// 테마는 읽지도 저장하지도 않는다. `@Shared(.appTheme)`가 저장소를 직접 읽어서
/// 표시할 값이 항상 있고, 하위 화면이 바꾼 값도 그대로 보인다.
@Reducer
public struct SettingFeature {

    // MARK: - Path

    /// 설정 안에서 끝나는 하위 화면들. 부모 리듀서와 같은 파일에 둬야 어떤 화면이 붙는지 함께 보인다.
    /// `public`인 이유: 데모앱이 특정 하위 화면으로 바로 진입할 때 `path`에 직접 넣는다.
    @Reducer
    public enum Path {
        case theme(ThemeFeature)
        case notification(NotificationSettingFeature)
        case account(AccountFeature)
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {

        /// 아직 불러오지 못했으면 `nil` — 헤더 자리를 비워 둔다.
        public var profile: SettingProfile?

        /// 사용자가 고른 테마. 저장소를 직접 읽어서 불러오는 단계가 없고,
        /// 테마 화면에서 고른 값도 바로 반영된다.
        @Shared(.appTheme) public var theme: AppTheme

        /// 프로필 조회 중. 테마는 로딩 표시가 필요 없다.
        public var isLoading = false

        @Presents public var alert: AlertState<Action.Alert>?

        /// 하위 화면 스택 (테마 / 알림 / 계정 관리).
        public var path = StackState<Path.State>()

        /// 테마 행에 표시할 값.
        public var themeDisplayName: String {
            theme.displayName
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

        /// 설정 **밖**으로 나가야 하는 것만 올린다. 하위 화면 이동은 `path`가 처리한다.
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            /// 프로필 편집 화면 — 이슈 #33의 별도 Feature 모듈이라 App이 띄운다 (규칙 3).
            case editProfileRequested
            case backRequested
            /// 로그아웃 완료 — App이 로그인 화면으로 되돌린다.
            case signedOut
            /// 회원 탈퇴 완료 — App이 로그인 화면으로 되돌린다.
            case accountDeleted
        }

        case delegate(Delegate)

        /// 내부 — 프로필 조회 결과 (실패 경로가 있어 `Result`).
        case profileResponse(Result<SettingProfile, SettingError>)

        /// 하위 화면 스택.
        case path(StackActionOf<Path>)

        /// 얼럿 (확인 버튼만 — 추가 액션이 없어 빈 enum).
        public enum Alert: Equatable, Sendable {}
        case alert(PresentationAction<Alert>)
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.loadProfileUseCase) var loadProfileUseCase
    @Dependency(\.settingExternalLinks) var externalLinks
    @Dependency(\.openURL) var openURL

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.onAppear):
                // 이미 불러왔으면 다시 부르지 않는다 — 하위 화면에서 돌아올 때마다 깜빡이지 않게.
                guard state.profile == nil, !state.isLoading else { return .none }
                state.isLoading = true
                // 테마는 여기서 읽지 않는다. `@Shared`가 저장소를 직접 읽어 이미 값이 있다.
                return .run { [loadProfileUseCase] send in
                    await send(.profileResponse(Result {
                        try await loadProfileUseCase.run()
                    }.mapToSettingError()))
                }
                .cancellable(id: CancelID.load, cancelInFlight: true)

            case let .profileResponse(.success(profile)):
                state.isLoading = false
                state.profile = profile
                // 조회가 늦게 끝나는 사이 이미 계정 관리로 들어가 있으면 그 화면에도 채운다.
                // 그 화면은 스스로 조회하지 않아 부모가 넣어주지 않으면 영영 빈 채로 남는다.
                fillAccountProfile(profile, in: &state.path)
                return .none

            case let .profileResponse(.failure(error)):
                state.isLoading = false
                // TODO: 얼럿 제목·버튼 문구는 임의 작성본 — 추후 기획 정책 확정 시 교체할 것.
                state.alert = AlertState {
                    TextState("프로필을 불러오지 못했어요")
                } actions: {
                    ButtonState(role: .cancel) { TextState("확인") }
                } message: {
                    TextState(error.userMessage)
                }
                return .none

            // MARK: - 하위 화면 push

            case .view(.themeRowTapped):
                state.path.append(.theme(ThemeFeature.State()))
                return .none

            case .view(.notificationRowTapped):
                state.path.append(.notification(NotificationSettingFeature.State()))
                return .none

            case .view(.accountRowTapped):
                state.path.append(.account(AccountFeature.State(profile: state.profile)))
                return .none

            // MARK: - 하위 화면 delegate

            case .path(.element(id: _, action: .account(.delegate(.signedOut)))):
                // 스택을 먼저 비운다 — App이 화면을 즉시 교체하지 않는 구현이어도
                // 이미 끝난 계정의 화면이 남아 있지 않게.
                state.path.removeAll()
                return .send(.delegate(.signedOut))

            case .path(.element(id: _, action: .account(.delegate(.accountDeleted)))):
                state.path.removeAll()
                return .send(.delegate(.accountDeleted))

            case .path:
                return .none

            // MARK: - 앱 밖으로

            case .view(.supportRowTapped):
                return open(externalLinks.appStoreReview())

            case .view(.feedbackRowTapped):
                return open(externalLinks.feedbackForm())

            // MARK: - App에 위임

            case .view(.editProfileButtonTapped):
                return .send(.delegate(.editProfileRequested))

            case .view(.backButtonTapped):
                return .send(.delegate(.backRequested))

            case .delegate, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .forEach(\.path, action: \.path)
    }

    // MARK: - Effects

    /// 스택에 떠 있는 계정 관리 화면에 프로필을 채운다.
    /// 계정 관리는 이 화면에서 한 번만 push되므로 첫 항목을 찾으면 끝난다.
    private func fillAccountProfile(_ profile: SettingProfile, in path: inout StackState<Path.State>) {
        guard let id = path.ids.first(where: { path[id: $0]?.is(\.account) == true }),
              case var .account(account) = path[id: id]
        else { return }
        account.profile = profile
        path[id: id] = .account(account)
    }

    /// 앱 밖 링크를 연다. 주소가 없거나(`SettingExternalLinks` 미확정) 열지 못해도 알리지 않는다 —
    /// 시안에 실패 문구가 없다.
    private func open(_ url: URL?) -> Effect<Action> {
        guard let url else { return .none }
        return .run { [openURL] _ in
            await openURL(url)
        }
    }

    private enum CancelID { case load }
}

// MARK: - Path conformances

// `@Reducer enum`이 만드는 State·Action에 프로토콜을 붙이는 자리 (파일 스코프여야 한다).
// extension으로 붙이는 이유: `@Reducer(state:action:)` 인자 형태는 TCA 1.26에서 deprecated 됐다.
// `Equatable`은 부모 State가 `StackState<Path.State>`를 담아서, `Sendable`은 부모 `Action` 때문에 필요하다.
extension SettingFeature.Path.State: Equatable, Sendable {}
extension SettingFeature.Path.Action: Sendable {}
