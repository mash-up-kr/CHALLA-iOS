import AuthDomain
import ComposableArchitecture

/// 로그인 화면의 TCA Feature.
///
/// 카카오/애플 버튼 탭을 받아 `LoginUseCase` 하나로 로그인 전 과정
/// (소셜 인증 → 서버 로그인 → 토큰 저장)을 실행한다.
@Reducer
public struct LoginFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        /// 로그인 진행 중인 provider (둘 다 비활성 + 해당 버튼 스피너). `nil`이면 유휴.
        public var inFlightProvider: AuthProvider?

        /// 온보딩 페이저에서 현재 보이는 페이지 인덱스 (0~4).
        public var onboardingPage = 0
        @Presents public var alert: AlertState<Action.Alert>?

        /// 진행 중인 provider가 있으면 두 버튼을 모두 비활성화한다.
        public var isLoading: Bool {
            inFlightProvider != nil
        }

        public init() {}
    }

    // MARK: - Action

    public enum Action: ViewAction, Sendable {

        /// UI에서만 트리거되는 액션 (`@ViewAction` 뷰가 `send(...)`로 호출).
        @CasePathable
        public enum ViewAction: Sendable {
            case kakaoLoginButtonTapped
            case appleLoginButtonTapped
            case onboardingPageChanged(Int)
        }

        case view(ViewAction)

        /// parent(App)에게만 알린다. 다음 화면은 App이 내 프로필을 다시 조회해 정한다.
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case loginSucceeded
        }

        case delegate(Delegate)

        /// 내부 — 비동기 로그인 결과.
        case loginResponse(Result<LoginResult, AuthError>)

        /// 얼럿 (확인 버튼만 — 추가 액션이 없어 빈 enum).
        public enum Alert: Equatable, Sendable {}
        case alert(PresentationAction<Alert>)
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.loginUseCase) var loginUseCase

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.kakaoLoginButtonTapped):
                return startLogin(&state, provider: .kakao)

            case .view(.appleLoginButtonTapped):
                return startLogin(&state, provider: .apple)

            case let .view(.onboardingPageChanged(page)):
                state.onboardingPage = page
                return .none

            case .loginResponse(.success):
                state.inFlightProvider = nil
                return .send(.delegate(.loginSucceeded))

            case let .loginResponse(.failure(error)):
                state.inFlightProvider = nil
                if case .cancelled = error {
                    return .none
                }
                // TODO: 얼럿 제목·버튼 문구는 임의 작성본 — 추후 기획 정책 확정 시 교체할 것.
                state.alert = AlertState {
                    TextState("로그인 실패")
                } actions: {
                    ButtonState(role: .cancel) { TextState("확인") }
                } message: {
                    TextState(error.userMessage)
                }
                return .none

            case .delegate, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    // MARK: - Effects

    private enum CancelID { case login }

    /// 중복 탭을 가드한 뒤 로그인 이펙트를 시작한다.
    /// useCase가 던지는 오류는 라이브 구현이 전부 `AuthError`로 정규화하므로,
    /// 그 외 오류는 방어적으로 `.unknown`으로 감싼다.
    private func startLogin(_ state: inout State, provider: AuthProvider) -> Effect<Action> {
        guard state.inFlightProvider == nil else { return .none }
        state.inFlightProvider = provider
        return .run { [loginUseCase] send in // 비-Sendable self 대신 의존성 값만 캡처
            do {
                let result = try await loginUseCase.run(provider)
                await send(.loginResponse(.success(result)))
            } catch let error as AuthError {
                await send(.loginResponse(.failure(error)))
            } catch is CancellationError {
                // 이펙트 취소(예: 화면 이탈) — 무시
            } catch {
                await send(.loginResponse(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.login, cancelInFlight: true)
    }
}
