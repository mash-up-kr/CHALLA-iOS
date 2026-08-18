import AuthDomain
import CameraFeature
import CameraSession
import ChatRoomFeature
import ComposableArchitecture
import HomeFeature
import LoginFeature
import PhotoDetailFeature
import ProfileSetupFeature
import RoomDetailFeature
import RoomDomain
import SettingFeature
import ShootEntry
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
        case photoDetail(PhotoDetailScreen)
        case chat(ChatScreen)
        case setting(SettingScreen)
        case profileEdit(ProfileEditScreen)
        case camera(CameraScreen)

        /// 강제 업데이트. 여기서 나가는 전이는 없다 — 앱을 지우거나 업데이트해야 끝난다.
        /// 연관값이 없는 이유: 알럿 문구는 상수고, 스토어 주소는 `AppUpdateClient`가 준다.
        case forceUpdate

        /// 화면 전환만 식별한다 — 자식 State 변화(닉네임 입력 등)에는 반응하지 않는다.
        public var screenID: ScreenID {
            switch self {
            case .launching: return .launching
            case .login: return .login
            case .profileSetup: return .profileSetup
            case .home: return .home
            case .roomDetail: return .roomDetail
            case .photoDetail: return .photoDetail
            case .chat: return .chat
            case .setting: return .setting
            case .profileEdit: return .profileEdit
            case .camera: return .camera
            case .forceUpdate: return .forceUpdate
            }
        }

        public enum ScreenID: Equatable, Sendable {
            case launching, login, profileSetup, home, roomDetail, photoDetail, chat, setting, profileEdit, camera
            case forceUpdate
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
        case sessionRestored(SessionRestoration)
        case sessionExpired
        case profileResponse(Result<UserProfile, UserError>)
        case login(LoginFeature.Action)
        case profileSetup(ProfileSetupFeature.Action)
        case home(HomeFeature.Action)
        case roomDetail(RoomDetailFeature.Action)
        case photoDetail(PhotoDetailFeature.Action)
        case chat(ChatRoomFeature.Action)
        case setting(SettingFeature.Action)
        case profileEdit(ProfileSetupFeature.Action)
        case camera(LiveCameraFeature.Action)

        /// 버전 체크 결과. 실패는 여기 오기 전에 `.notRequired`로 접힌다 (fail-open).
        case updateCheckResponse(AppUpdateRequirement)
        /// 강제 업데이트 알럿의 '확인'.
        case forceUpdateConfirmTapped
    }

    // MARK: - Init

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.fetchMyProfileUseCase) var fetchMyProfileUseCase
    @Dependency(\.restoreSessionUseCase) var restoreSessionUseCase
    @Dependency(\.sessionExpirationChannel) var sessionExpirationChannel
    @Dependency(\.continuousClock) var clock
    @Dependency(\.pushTokenSynchronizer) var pushTokenSynchronizer
    @Dependency(\.appUpdateClient) var appUpdateClient
    @Dependency(\.openURL) var openURL

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        core
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
            .ifCaseLet(\.photoDetail, action: \.photoDetail) {
                Scope(state: \.photoDetail, action: \.self) {
                    PhotoDetailFeature()
                }
            }
            .ifCaseLet(\.chat, action: \.chat) {
                Scope(state: \.chat, action: \.self) {
                    ChatRoomFeature()
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
}

// MARK: - 화면 전이

extension AppFeature {

    /// 상태 전이 코어. `.ifCaseLet` 체인과 한 표현식에 두면 타입 추론이 오래 걸려(특히 Xcode 27)
    /// 코어를 별도 프로퍼티로 분리해 빌더 표현식을 가볍게 만든다.
    private var core: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return checkAppUpdate()

            // 세션 복원은 버전 체크를 통과한 뒤에 시작한다 — 강제 업데이트 화면에서는 아무것도 조회하지 않는다.
            case .updateCheckResponse(.notRequired):
                return .merge(restoreSession(), observeSessionExpiration())

            case .updateCheckResponse(.forced):
                // 여기서 나가는 전이는 없다. 업데이트해야만 앱을 쓸 수 있다.
                state = .forceUpdate
                return .none

            case .forceUpdateConfirmTapped:
                guard let url = appUpdateClient.appStoreURL() else { return .none }
                return .run { [openURL] _ in await openURL(url) }

            case .sessionRestored(.restored):
                return fetchMyProfile()

            case .sessionRestored(.signedOut):
                state = .login(LoginFeature.State())
                return .none

            case .sessionExpired:
                guard state.screenID != .login else { return .none }
                state = .login(LoginFeature.State())
                return .cancel(id: CancelID.profile)

            case let .profileResponse(.success(profile)):
                // 늦게 도착한 프로필 응답이 강제 업데이트 화면을 덮지 못하게 하는 방어선.
                guard case .launching = state else { return .none }
                state = profile.isProfileCompleted
                    ? .home(HomeScreen(profile: profile))
                    : .profileSetup(ProfileSetupFeature.State())
                return .none

            case .profileResponse(.failure):
                guard case .launching = state else { return .none }
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

            // 진입 버튼이 방·필터·권한을 모두 갖춘 뒤에만 오는 요청이라 여기서 바로 띄운다.
            case let .home(.delegate(.cameraRequested(entry))):
                guard case let .home(screen) = state else { return .none }
                state = .camera(
                    CameraScreen(profile: screen.profile, entry: entry, origin: .home)
                )
                return .none

            // MARK: - 방 상세 delegate

            case .roomDetail(.delegate(.closeTapped)):
                guard case let .roomDetail(screen) = state else { return .none }
                // 홈 State를 새로 만들어 목록을 다시 조회한다 — 방에서 사진을 찍고 나왔을 수 있다.
                state = .home(HomeScreen(profile: screen.profile))
                return .none

            // 방 상세에서 채팅 버튼 — 방 채팅 화면으로 들어간다.
            case .roomDetail(.delegate(.chatTapped)):
                guard case let .roomDetail(screen) = state else { return .none }
                state = .chat(ChatScreen(profile: screen.profile, room: screen.roomDetail.room))
                return .none

            case let .roomDetail(.delegate(.cameraRequested(entry))):
                guard case let .roomDetail(screen) = state else { return .none }
                state = .camera(
                    CameraScreen(
                        profile: screen.profile,
                        entry: entry,
                        origin: .roomDetail(screen.roomDetail.room)
                    )
                )
                return .none

            // 슬롯의 사진을 탭 — 그 사진을 펼친 채 사진 상세로 들어간다.
            case let .roomDetail(.delegate(.photoTapped(photoID))):
                guard case let .roomDetail(screen) = state else { return .none }
                state = .photoDetail(
                    PhotoDetailScreen(
                        profile: screen.profile,
                        room: screen.roomDetail.room,
                        initialPhotoID: photoID
                    )
                )
                return .none

            // MARK: - 사진 상세 delegate

            case .photoDetail(.delegate(.closeRequested)):
                guard case let .photoDetail(screen) = state else { return .none }
                // 방 상세를 다시 만든다 — 상세로 돌아가면 사진·리액션을 새로 조회해 최신 상태를 그린다.
                state = .roomDetail(RoomDetailScreen(profile: screen.profile, room: screen.room))
                return .none

            // MARK: - 채팅 delegate

            case .chat(.delegate(.closeRequested)):
                guard case let .chat(screen) = state else { return .none }
                // 방 상세를 다시 만든다 — 돌아가면 사진·리액션을 새로 조회해 최신 상태를 그린다.
                state = .roomDetail(RoomDetailScreen(profile: screen.profile, room: screen.room))
                return .none

            // MARK: - 카메라 delegate

            // 들어온 화면을 새로 만들어 되돌린다 — 촬영으로 남은 장수·사진이 바뀌었을 수 있어 다시 조회된다.
            case .camera(.camera(.delegate(.closeRequested))):
                guard case let .camera(screen) = state else { return .none }
                switch screen.origin {
                case .home:
                    state = .home(HomeScreen(profile: screen.profile))
                case let .roomDetail(room):
                    state = .roomDetail(RoomDetailScreen(profile: screen.profile, room: room))
                }
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

            case .login, .profileSetup, .home, .roomDetail, .photoDetail, .chat, .setting, .profileEdit, .camera:
                return .none
            }
        }
    }
}

// MARK: - PhotoDetailScreen

public extension AppFeature {

    /// 사진 상세 화면 State + 뒤로 갈 때 복원할 방·프로필.
    ///
    /// `State`가 enum이라 사진 상세로 오면 방 상세 State가 사라진다. 뒤로가기로 방 상세를 다시 만들 때
    /// 쓸 방과 프로필을 여기 맡아 둔다 (방 상세→홈 복귀가 프로필을 들고 다니는 것과 같은 이유).
    @ObservableState
    struct PhotoDetailScreen: Equatable {
        public var profile: UserProfile
        public var room: Room
        public var photoDetail: PhotoDetailFeature.State

        public init(profile: UserProfile, room: Room, initialPhotoID: String) {
            self.profile = profile
            self.room = room
            self.photoDetail = PhotoDetailFeature.State(
                roomID: room.id,
                roomTitle: room.title,
                // 리액션을 남기는 주체 = 지금 보는 사람. PhotoReaction.userID(String)와 맞춘다.
                currentUserID: String(profile.id),
                // 인화 완료 전이면 방 상세처럼 사진을 blur로 가린다.
                isPrinted: room.status == .printed,
                initialPhotoID: initialPhotoID
            )
        }
    }
}

// MARK: - CameraScreen

public extension AppFeature {

    /// 카메라 화면 State + 닫을 때 돌아갈 곳.
    ///
    /// 방·필터 목록은 진입 버튼(홈의 촬영 뱃지 · 방 상세의 사진 찍기)이 미리 받아 둔 것을 그대로 옮겨 담는다 —
    /// 카메라 화면은 목록을 스스로 조회하지 않는다.
    @ObservableState
    struct CameraScreen: Equatable {
        public var profile: UserProfile
        /// 어디서 들어왔는지. 카메라를 닫으면 여기로 되돌린다.
        public var origin: CameraOrigin
        /// 카메라 화면 + 실기기 촬영 배선(`CameraSession`).
        public var live: LiveCameraFeature.State

        public init(profile: UserProfile, entry: CameraEntry, origin: CameraOrigin) {
            self.profile = profile
            self.origin = origin
            live = LiveCameraFeature.State(
                camera: CameraFeature.State(
                    rooms: IdentifiedArray(uniqueElements: entry.rooms),
                    filters: IdentifiedArray(uniqueElements: entry.filters),
                    selectedRoomID: entry.roomID
                )
            )
        }
    }

    /// 카메라를 닫았을 때 돌아갈 화면. 방 상세로 돌아가려면 그 방이 필요해 함께 들고 있는다 —
    /// `State`가 enum이라 카메라로 오면 앞 화면의 State는 사라진다.
    enum CameraOrigin: Equatable {
        case home
        case roomDetail(Room)
    }
}

// MARK: - ChatScreen

public extension AppFeature {

    /// 방 채팅 화면 State + 뒤로 갈 때 복원할 방·프로필.
    ///
    /// `State`가 enum이라 채팅으로 오면 방 상세 State가 사라진다. 뒤로가기로 방 상세를 다시 만들 때
    /// 쓸 방과 프로필을 여기 맡아 둔다 (PhotoDetailScreen과 같은 이유).
    @ObservableState
    struct ChatScreen: Equatable {
        public var profile: UserProfile
        public var room: Room
        public var chat: ChatRoomFeature.State

        public init(profile: UserProfile, room: Room) {
            self.profile = profile
            self.room = room
            self.chat = ChatRoomFeature.State(
                roomID: room.id,
                roomTitle: room.title,
                // 내 메시지(오른쪽 흰 버블) 판별 기준. 서버가 userId를 주면 그때 교체한다.
                currentUserNickname: profile.nickname ?? ""
            )
        }
    }
}

// MARK: - Effects

extension AppFeature {

    private enum CancelID { case profile, sessionExpiration, updateCheck }

    /// 실행 직후 1회 버전 체크.
    /// 실패는 `.notRequired`로 접는다 — 체크 서버가 죽었다고 전 사용자 앱을 스플래시에 가둘 수는 없다.
    private func checkAppUpdate() -> Effect<Action> {
        .run { [appUpdateClient] send in
            // 취소되면 send 자체가 무시되므로 try? 가 취소를 .notRequired 로 오인해도 화면이 진행되지 않는다.
            let requirement = await (try? appUpdateClient.checkRequirement()) ?? .notRequired
            await send(.updateCheckResponse(requirement))
        }
        .cancellable(id: CancelID.updateCheck, cancelInFlight: true)
    }

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

    /// 저장된 세션이 있을 때만 프로필을 조회한다 — 없으면 실패할 요청을 보내지 않고 곧바로 로그인 화면으로 간다.
    private func restoreSession() -> Effect<Action> {
        .run { [restoreSessionUseCase] send in
            await send(.sessionRestored(restoreSessionUseCase.run()))
        }
    }

    /// 토큰 갱신이 최종 실패하면(재로그인 필요) 어느 화면에 있든 로그인으로 되돌린다.
    private func observeSessionExpiration() -> Effect<Action> {
        .run { [sessionExpirationChannel] send in
            for await _ in sessionExpirationChannel.events {
                await send(.sessionExpired)
            }
        }
        .cancellable(id: CancelID.sessionExpiration, cancelInFlight: true)
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
