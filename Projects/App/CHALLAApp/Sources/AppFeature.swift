import ComposableArchitecture
import LoginFeature
import ProfileSetupFeature
import UserDomain

/// 앱 루트 리듀서 — 진입할 때마다 내 프로필을 조회해 첫 화면을 고르고, 로그인·프로필 설정이 끝나면 다음 화면으로 넘긴다.
@Reducer
public struct AppFeature {

    // MARK: - State

    /// 앱의 큰 흐름 단계. 동시에 두 화면이 살아 있을 수 없으므로 enum으로 못 박는다.
    @ObservableState
    public enum State: Equatable {
        case launching
        case login(LoginFeature.State)
        case profileSetup(ProfileSetupFeature.State)
        // TODO: HomeFeature가 생기면 그 State로 교체할 것.
        case home(UserProfile)

        /// 화면 전환만 식별한다 — 자식 State 변화(닉네임 입력 등)에는 반응하지 않는다.
        public var screenID: ScreenID {
            switch self {
            case .launching: return .launching
            case .login: return .login
            case .profileSetup: return .profileSetup
            case .home: return .home
            }
        }

        public enum ScreenID: Equatable, Sendable {
            case launching, login, profileSetup, home
        }
    }

    // MARK: - Action

    public enum Action {
        case task
        case profileResponse(Result<UserProfile, UserError>)
        case login(LoginFeature.Action)
        case profileSetup(ProfileSetupFeature.Action)
    }

    // MARK: - Init

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.fetchMyProfileUseCase) var fetchMyProfileUseCase
    @Dependency(\.continuousClock) var clock

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return fetchMyProfile()

            case let .profileResponse(.success(profile)):
                state = profile.isProfileCompleted
                    ? .home(profile)
                    : .profileSetup(ProfileSetupFeature.State())
                return .none

            case .profileResponse(.failure):
                // 재시도로 풀리는 실패는 여기까지 오지 않는다(이펙트가 삼킨다) — 남는 건 로그인부터 다시 해야 하는 것들뿐.
                state = .login(LoginFeature.State())
                return .none

            case .login(.delegate(.loginSucceeded)):
                state = .launching
                return fetchMyProfile()

            case let .profileSetup(.delegate(.setupCompleted(profile))):
                state = .home(profile)
                return .none

            case .login, .profileSetup:
                return .none
            }
        }
        .ifCaseLet(\.login, action: \.login) {
            LoginFeature()
        }
        .ifCaseLet(\.profileSetup, action: \.profileSetup) {
            ProfileSetupFeature()
        }
    }

    private enum CancelID { case profile }

    /// 저절로 풀릴 수 있는 실패가 이어지는 동안의 대기 간격. 마지막 값이 상한이다.
    private enum RetryBackoff {
        private static let delays: [Duration] = [.seconds(1), .seconds(2), .seconds(4)]

        static func delay(for attempt: Int) -> Duration {
            delays[min(attempt, delays.count - 1)]
        }
    }

    private func fetchMyProfile() -> Effect<Action> {
        .run { [fetchMyProfileUseCase, clock] send in
            for attempt in 0... {
                do {
                    let profile = try await fetchMyProfileUseCase.run()
                    await send(.profileResponse(.success(profile)))
                    return
                } catch is CancellationError {
                    return
                } catch let error as UserError where error.isRetryable {
                    // 전파·서버 일시 장애는 사용자가 손쓸 수 있는 게 없다 — 알리지 않고 아래에서 대기 후 재시도한다.
                } catch {
                    await send(.profileResponse(.failure((error as? UserError) ?? .unknown)))
                    return
                }

                // try? 로 감싸면 취소된 뒤에도 루프가 계속 돈다 — 취소는 그대로 밖으로 던진다.
                try await clock.sleep(for: RetryBackoff.delay(for: attempt))
            }
        }
        .cancellable(id: CancelID.profile, cancelInFlight: true)
    }
}
