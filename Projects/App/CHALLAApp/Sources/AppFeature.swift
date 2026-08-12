import ComposableArchitecture
import HomeFeature
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
        case home(HomeFeature.State)

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
        case home(HomeFeature.Action)
    }

    // MARK: - Init

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.fetchMyProfileUseCase) var fetchMyProfileUseCase

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return fetchMyProfile()

            case let .profileResponse(.success(profile)):
                state = profile.isProfileCompleted
                    ? .home(Self.homeState(for: profile))
                    : .profileSetup(ProfileSetupFeature.State())
                return .none

            case .profileResponse(.failure):
                // 미로그인(401)도 조회 실패도 결론은 같다 — 로그인부터 다시.
                state = .login(LoginFeature.State())
                return .none

            case .login(.delegate(.loginSucceeded)):
                state = .launching
                return fetchMyProfile()

            case let .profileSetup(.delegate(.setupCompleted(profile))):
                state = .home(Self.homeState(for: profile))
                return .none

            // 홈이 알리는 화면 전환 요청 — Feature끼리는 서로를 모르므로 조립은 App이 한다 (규칙 3).
            case .home(.delegate(.roomSelected)):
                // TODO: 방 상세 Feature가 생기면 여기서 push한다.
                return .none

            case .home(.delegate(.settingsTapped)):
                // TODO: 설정 앱 연결(#50)이 머지되면 여기서 SettingFeature를 연다.
                return .none

            case .home(.delegate(.roomCreated)), .home(.delegate(.roomJoined)):
                // TODO: 방 상세 Feature가 생기면 만든·입장한 방으로 바로 진입할지 기획과 정해 여기서 조립한다.
                return .none

            case .login, .profileSetup, .home:
                return .none
            }
        }
        .ifCaseLet(\.login, action: \.login) {
            LoginFeature()
        }
        .ifCaseLet(\.profileSetup, action: \.profileSetup) {
            ProfileSetupFeature()
        }
        .ifCaseLet(\.home, action: \.home) {
            HomeFeature()
        }
    }

    /// 로그인 뒤 조회한 내 프로필을 홈의 시작 State로 옮겨 담는다 — 홈의 인사말·프로필 아바타가 이 값으로 그려진다.
    /// 홈으로 들어오는 문이 둘(프로필 조회 성공·프로필 설정 완료)이라 변환 규칙을 한곳에 모았다.
    private static func homeState(for profile: UserProfile) -> HomeFeature.State {
        HomeFeature.State(
            nickname: profile.nickname ?? "",
            profileImageURL: profile.imageURL
        )
    }

    private enum CancelID { case profile }

    private func fetchMyProfile() -> Effect<Action> {
        .run { [fetchMyProfileUseCase] send in
            do {
                let profile = try await fetchMyProfileUseCase.run()
                await send(.profileResponse(.success(profile)))
            } catch let error as UserError {
                await send(.profileResponse(.failure(error)))
            } catch is CancellationError {
            } catch {
                await send(.profileResponse(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.profile, cancelInFlight: true)
    }
}
