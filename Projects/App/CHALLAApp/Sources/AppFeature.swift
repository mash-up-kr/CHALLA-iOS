import CameraFeature
import CameraSession
import ComposableArchitecture
import HomeFeature
import LoginFeature
import ProfileSetupFeature
import RoomDetailFeature
import RoomDomain
import SettingFeature
import UserDomain

/// 앱 루트 리듀서 — 진입할 때마다 내 프로필을 조회해 첫 화면을 고르고, 각 화면이 끝나면 다음 화면으로 넘긴다.
@Reducer
public struct AppFeature {

    // MARK: - State

    /// 앱의 큰 흐름 단계. 동시에 두 화면이 살아 있을 수 없으므로 enum으로 못 박는다.
    @ObservableState
    public enum State: Equatable {
        case launching
        case login(LoginFeature.State)
        case profileSetup(ProfileSetupFeature.State)
        case home(HomeScreen)
        case roomDetail(RoomDetailScreen)
        case setting(SettingScreen)
        case profileEdit(ProfileEditScreen)
        case camera(CameraScreen)

        /// 화면 전환만 식별한다 — 자식 State 변화(닉네임 입력 등)에는 반응하지 않는다.
        public var screenID: ScreenID {
            switch self {
            case .launching: return .launching
            case .login: return .login
            case .profileSetup: return .profileSetup
            case .home: return .home
            case .roomDetail: return .roomDetail
            case .setting: return .setting
            case .profileEdit: return .profileEdit
            case .camera: return .camera
            }
        }

        public enum ScreenID: Equatable, Sendable {
            case launching, login, profileSetup, home, roomDetail, setting, profileEdit, camera
        }
    }

    /// 홈 화면 State + 설정으로 넘길 프로필.
    ///
    /// `HomeFeature.State`는 인사말용 닉네임·이미지만 들고 있다. 설정·프로필 편집은 전체 `UserProfile`이
    /// 필요해서, 홈에 들어올 때 받은 프로필을 여기 함께 두었다가 설정 진입 때 넘긴다.
    @ObservableState
    public struct HomeScreen: Equatable {
        public var profile: UserProfile
        public var home: HomeFeature.State

        public init(profile: UserProfile) {
            self.profile = profile
            self.home = HomeFeature.State(
                nickname: profile.nickname ?? "",
                profileImageURL: profile.imageURL
            )
        }
    }

    /// 방 상세 화면 State + 홈으로 돌아갈 때 쓸 프로필.
    ///
    /// `State`가 enum이라 방 상세로 오면 홈 State는 사라진다. 뒤로가기로 홈을 다시 만들 때
    /// 인사말에 쓸 프로필이 필요한데, 안 들고 오면 서버를 다시 조회해야 하고 그동안 화면이 빈다.
    /// 방 상세 화면 자체는 이 프로필을 쓰지 않는다 — 돌아갈 때까지 맡아두는 값이다.
    @ObservableState
    public struct RoomDetailScreen: Equatable {
        public var profile: UserProfile
        public var roomDetail: RoomDetailFeature.State

        public init(profile: UserProfile, room: Room) {
            self.profile = profile
            self.roomDetail = RoomDetailFeature.State(room: room)
        }
    }

    /// 설정 화면 State + 홈 복귀용 프로필.
    ///
    /// 프로필을 함께 두는 이유: 홈이 닉네임을 표시하는데, 설정에서 뒤로가면 재조회 없이 바로 그려야 한다.
    @ObservableState
    public struct SettingScreen: Equatable {
        public var profile: UserProfile
        public var setting: SettingFeature.State

        public init(profile: UserProfile, setting: SettingFeature.State = .init()) {
            self.profile = profile
            self.setting = setting
        }
    }

    /// 카메라 화면 State + 홈 복귀용 프로필.
    ///
    /// 방·필터 목록은 홈의 촬영 버튼이 미리 받아 둔 것을 그대로 옮겨 담는다 —
    /// 카메라 화면은 목록을 스스로 조회하지 않는다.
    @ObservableState
    public struct CameraScreen: Equatable {
        public var profile: UserProfile
        /// 카메라 화면 + 실기기 촬영 배선(`CameraSession`).
        public var live: LiveCameraFeature.State

        public init(profile: UserProfile, entry: CameraEntry) {
            self.profile = profile
            live = LiveCameraFeature.State(
                camera: CameraFeature.State(
                    rooms: IdentifiedArray(uniqueElements: entry.rooms),
                    filters: IdentifiedArray(uniqueElements: entry.filters),
                    selectedRoomID: entry.roomID
                )
            )
        }
    }

    /// 프로필 편집 화면 State + 취소 시 복원할 프로필.
    @ObservableState
    public struct ProfileEditScreen: Equatable {
        public var profile: UserProfile
        public var edit: ProfileSetupFeature.State

        public init(profile: UserProfile) {
            self.profile = profile
            self.edit = ProfileSetupFeature.State(
                mode: .edit,
                nickname: profile.nickname ?? "",
                remoteImageURL: profile.imageURL
            )
        }
    }

    // MARK: - Action

    public enum Action {
        case task
        case profileResponse(Result<UserProfile, UserError>)
        case login(LoginFeature.Action)
        case profileSetup(ProfileSetupFeature.Action)
        case home(HomeFeature.Action)
        case roomDetail(RoomDetailFeature.Action)
        case setting(SettingFeature.Action)
        case profileEdit(ProfileSetupFeature.Action)
        case camera(LiveCameraFeature.Action)
    }

    // MARK: - Init

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.fetchMyProfileUseCase) var fetchMyProfileUseCase
    @Dependency(\.continuousClock) var clock
    @Dependency(\.pushTokenSynchronizer) var pushTokenSynchronizer

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return fetchMyProfile()

            case let .profileResponse(.success(profile)):
                state = profile.isProfileCompleted
                    ? .home(HomeScreen(profile: profile))
                    : .profileSetup(ProfileSetupFeature.State())
                return .none

            case .profileResponse(.failure):
                // 미로그인(401)도 조회 실패도 결론은 같다 — 로그인부터 다시.
                state = .login(LoginFeature.State())
                return .none

            case .login(.delegate(.loginSucceeded)):
                state = .launching
                // 여기서 한번 sync 처리.
                return .merge(
                    fetchMyProfile(),
                    .run { [pushTokenSynchronizer] _ in await pushTokenSynchronizer.sync() }
                )

            case let .profileSetup(.delegate(.setupCompleted(profile))):
                state = .home(HomeScreen(profile: profile))
                return .none

            // MARK: - 홈 delegate

            // 홈이 알리는 화면 전환 요청 — Feature끼리는 서로를 모르므로 조립은 App이 한다 (규칙 3).
            case .home(.delegate(.settingsTapped)):
                guard case let .home(screen) = state else { return .none }
                state = .setting(SettingScreen(profile: screen.profile))
                return .none

            // 목록에서 고른 방, 방금 만든 방, 초대 코드로 들어간 방 모두 상세로 들어간다.
            case let .home(.delegate(.roomSelected(card))),
                 let .home(.delegate(.roomCreated(card))),
                 let .home(.delegate(.roomJoined(card))):
                guard case let .home(screen) = state else { return .none }
                state = .roomDetail(RoomDetailScreen(profile: screen.profile, room: card.room))
                return .none

            // MARK: - 방 상세 delegate

            case .roomDetail(.delegate(.closeTapped)):
                guard case let .roomDetail(screen) = state else { return .none }
                // 홈 State를 새로 만들어 목록을 다시 조회한다 — 방에서 사진을 찍고 나왔을 수 있다.
                state = .home(HomeScreen(profile: screen.profile))
                return .none

            case .roomDetail(.delegate(.shootTapped)):
                // TODO: CameraFeature로 연결한다. 촬영을 마치고 방 상세로 돌아오는 흐름까지 함께 정한다.
                return .none

            case .roomDetail(.delegate(.chatTapped)):
                // TODO: 채팅 모듈이 생기면 연결한다.
                return .none

            // 홈이 방·필터·카메라 권한을 모두 갖춘 뒤에만 오는 요청이라 여기서 바로 띄운다.
            case let .home(.delegate(.cameraRequested(entry))):
                guard case let .home(screen) = state else { return .none }
                state = .camera(CameraScreen(profile: screen.profile, entry: entry))
                return .none

            // MARK: - 카메라 delegate

            // 홈을 새로 만들어 방 목록을 다시 받는다 — 촬영으로 남은 장수가 줄었을 수 있다.
            case .camera(.camera(.delegate(.closeRequested))):
                guard case let .camera(screen) = state else { return .none }
                state = .home(HomeScreen(profile: screen.profile))
                return .none

            // MARK: - 설정 delegate

            case .setting(.delegate(.backRequested)):
                guard case let .setting(screen) = state else { return .none }
                state = .home(HomeScreen(profile: screen.profile))
                return .none

            case .setting(.delegate(.editProfileRequested)):
                guard case let .setting(screen) = state else { return .none }
                state = .profileEdit(ProfileEditScreen(profile: screen.profile))
                return .none

            case .setting(.delegate(.signedOut)), .setting(.delegate(.accountDeleted)):
                state = .login(LoginFeature.State())
                return .none

            // MARK: - 프로필 편집 delegate

            case let .profileEdit(.delegate(.editCompleted(profile))):
                // 설정 State를 새로 만들어 헤더가 바뀐 닉네임을 다시 읽게 한다
                // (`onAppear`가 `profile == nil`일 때만 조회한다).
                state = .setting(SettingScreen(profile: profile))
                return .none

            case .profileEdit(.delegate(.cancelled)):
                guard case let .profileEdit(screen) = state else { return .none }
                state = .setting(SettingScreen(profile: screen.profile))
                return .none

            case .login, .profileSetup, .home, .roomDetail, .setting, .profileEdit, .camera:
                return .none
            }
        }
        .ifCaseLet(\.login, action: \.login) {
            LoginFeature()
        }
        .ifCaseLet(\.profileSetup, action: \.profileSetup) {
            ProfileSetupFeature()
        }
        // 래퍼(HomeScreen·SettingScreen·ProfileEditScreen)를 한 겹 벗겨 자식 리듀서에 넘긴다.
        .ifCaseLet(\.home, action: \.home) {
            Scope(state: \.home, action: \.self) {
                HomeFeature()
            }
        }
        .ifCaseLet(\.roomDetail, action: \.roomDetail) {
            Scope(state: \.roomDetail, action: \.self) {
                RoomDetailFeature()
            }
        }
        .ifCaseLet(\.setting, action: \.setting) {
            Scope(state: \.setting, action: \.self) {
                SettingFeature()
            }
        }
        .ifCaseLet(\.profileEdit, action: \.profileEdit) {
            Scope(state: \.edit, action: \.self) {
                ProfileSetupFeature()
            }
        }
        .ifCaseLet(\.camera, action: \.camera) {
            Scope(state: \.live, action: \.self) {
                LiveCameraFeature()
            }
        }
    }

    private enum CancelID { case profile }

    /// 저절로 풀릴 수 있는 실패가 이어질 때의 재시도 정책.
    private enum RetryBackoff {
        /// 첫 시도를 포함한 총 시도 횟수. 상한이 없으면 화면이 스플래시에 멈춘 채 빠져나가지 못한다.
        static let maxAttempts = 5

        /// 시도 사이의 대기 간격. 마지막 값이 상한이다.
        private static let delays: [Duration] = [.seconds(1), .seconds(2), .seconds(4)]

        static func delay(for attempt: Int) -> Duration {
            delays[min(attempt, delays.count - 1)]
        }
    }

    private func fetchMyProfile() -> Effect<Action> {
        .run { [fetchMyProfileUseCase, clock] send in
            for attempt in 0 ..< RetryBackoff.maxAttempts {
                do {
                    let profile = try await fetchMyProfileUseCase.run()
                    await send(.profileResponse(.success(profile)))
                    return
                } catch is CancellationError {
                    return
                } catch let error as UserError
                    where error.isRetryable && attempt < RetryBackoff.maxAttempts - 1 {
                    // 사용자가 손쓸 수 없는 실패다 — 알리지 않고 아래에서 대기 후 재시도한다.
                } catch {
                    // 재시도로 풀리지 않는 실패와 마지막 시도의 실패가 함께 여기로 온다.
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
