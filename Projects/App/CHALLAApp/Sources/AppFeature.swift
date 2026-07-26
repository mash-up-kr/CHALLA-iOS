import AuthDomain
import ComposableArchitecture
import LoginFeature

/// 앱 루트 리듀서 — 로그인 화면을 품고, 로그인 성공 시 다음 단계로 전환한다.
@Reducer
public struct AppFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var login = LoginFeature.State()
        public var phase: Phase = .login

        public init() {}
    }

    /// 앱의 큰 흐름 단계. 로그인 이후 화면(프로필 설정/메인)은 아직 모듈이 없어 placeholder로 둔다.
    public enum Phase: Equatable, Sendable {
        case login
        // TODO: ProfileSetupFeature / HomeFeature가 생기면 각각의 State로 교체할 것.
        //       isNewUser == true → 프로필 설정, false → 홈(방 목록) (분기 자체는 App 책임).
        case authenticated(isNewUser: Bool)
    }

    // MARK: - Action

    public enum Action {
        case login(LoginFeature.Action)
    }

    // MARK: - Init

    public init() {}

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Scope(state: \.login, action: \.login) {
            LoginFeature()
        }

        Reduce { state, action in
            switch action {
            case let .login(.delegate(.loginSucceeded(isNewUser))):
                state.phase = .authenticated(isNewUser: isNewUser)
                return .none

            case .login:
                return .none
            }
        }
    }
}
