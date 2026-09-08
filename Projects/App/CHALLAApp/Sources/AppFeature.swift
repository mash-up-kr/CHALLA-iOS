import AppDomain
import AuthDomain
import CameraFeature
import CameraSession
import ChatRoomFeature
import ComposableArchitecture
import Foundation
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
        case launching(SplashScreen)
        case login(LoginFeature.State)
        case profileSetup(ProfileSetupFeature.State)
        case home(HomeScreen)
        case roomDetail(RoomDetailScreen)
        case roomSettings(RoomSettingsScreen)
        case roomCoverEdit(RoomCoverEditScreen)
        case photoDetail(PhotoDetailScreen)
        case chat(ChatScreen)
        case setting(SettingScreen)
        case profileEdit(ProfileEditScreen)
        case camera(CameraScreen)

        /// 강제 업데이트. 여기서 나가는 전이는 없다 — 앱을 지우거나 업데이트해야 끝난다.
        /// `storeURL`은 버전 체크 응답에 실려 온 스토어 주소 — '확인'이 연다 (nil이면 아무 것도 안 한다).
        case forceUpdate(storeURL: URL?)

        /// 화면 전환만 식별한다 — 자식 State 변화(닉네임 입력 등)에는 반응하지 않는다.
        public var screenID: ScreenID {
            switch self {
            case .launching: return .launching
            case .login: return .login
            case .profileSetup: return .profileSetup
            case .home: return .home
            case .roomDetail: return .roomDetail
            case .roomSettings: return .roomSettings
            case .roomCoverEdit: return .roomCoverEdit
            case .photoDetail: return .photoDetail
            case .chat: return .chat
            case .setting: return .setting
            case .profileEdit: return .profileEdit
            case .camera: return .camera
            case .forceUpdate: return .forceUpdate
            }
        }

        /// 현재 화면이 들고 있는 내 프로필. 로그인 전 화면(스플래시·로그인·프로필 설정·강제 업데이트)에는
        /// 없다 — 초대 링크가 왔을 때 "지금 입장할 수 있는 상태인가"의 판별값.
        public var profile: UserProfile? {
            switch self {
            case .launching, .login, .profileSetup, .forceUpdate: return nil
            case let .home(screen): return screen.profile
            case let .roomDetail(screen): return screen.profile
            case let .roomSettings(screen): return screen.profile
            case let .roomCoverEdit(screen): return screen.profile
            case let .photoDetail(screen): return screen.profile
            case let .chat(screen): return screen.profile
            case let .setting(screen): return screen.profile
            case let .profileEdit(screen): return screen.profile
            case let .camera(screen): return screen.profile
            }
        }

        public enum ScreenID: Equatable, Sendable {
            case launching, login, profileSetup, home, roomDetail, roomSettings, roomCoverEdit
            case photoDetail, chat, setting, profileEdit, camera
            case forceUpdate
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
        case roomSettings(RoomSettingsFeature.Action)
        case roomCoverEdit(RoomCoverEditFeature.Action)
        case photoDetail(PhotoDetailFeature.Action)
        case chat(ChatRoomFeature.Action)
        case setting(SettingFeature.Action)
        case profileEdit(ProfileSetupFeature.Action)
        case camera(LiveCameraFeature.Action)

        /// 버전 체크 결과. 실패는 여기 오기 전에 `.notRequired`로 접힌다 (fail-open).
        case updateCheckResponse(AppUpdateRequirement)
        /// 스플래시 최소 노출 시간이 끝났다. 맡아둔 다음 화면이 있으면 그리로 전이한다.
        case splashMinimumHoldFinished
        /// 강제 업데이트 알럿의 '확인'.
        case forceUpdateConfirmTapped
        /// 커버 화면을 스와이프로 닫으며 맡긴 저장이 실패했다 — 맡아 둔 방의 커버를 저장 전 값으로 되돌린다.
        case roomCoverSaveFailed(roomID: Room.ID, previousCover: RoomCover)
        /// 엣지 스와이프 pop 제스처 완료. 자식의 뒤로가기 delegate와 같은 곳으로 되돌린다.
        case popGestureCompleted

        /// 유니버설 링크로 열렸다 — 초대 링크면 입장을 잇는다.
        case inviteLinkOpened(URL)

        /// 화면 밖에서 방을 열어 달라는 요청 (참여 토스트 탭).
        case openRoomRequested(Room)
    }

    // MARK: - Init

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.fetchMyProfileUseCase) var fetchMyProfileUseCase
    @Dependency(\.restoreSessionUseCase) var restoreSessionUseCase
    @Dependency(\.sessionExpirationChannel) var sessionExpirationChannel
    @Dependency(\.continuousClock) var clock
    @Dependency(\.pushTokenSynchronizer) var pushTokenSynchronizer
    @Dependency(\.checkAppUpdateUseCase) var checkAppUpdateUseCase
    @Dependency(\.openURL) var openURL
    @Dependency(\.updateRoomCoverUseCase) var updateRoomCoverUseCase
    @Dependency(\.pendingInviteCode) var pendingInviteCode

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
            .ifCaseLet(\.roomSettings, action: \.roomSettings) {
                Scope(state: \.settings, action: \.self) {
                    RoomSettingsFeature()
                }
            }
            .ifCaseLet(\.roomCoverEdit, action: \.roomCoverEdit) {
                Scope(state: \.coverEdit, action: \.self) {
                    RoomCoverEditFeature()
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
                // 버전 체크는 실행 직후 1회다 — 뷰 재생성으로 task가 다시 와도 재검사하지 않는다.
                guard case .launching = state else { return .none }
                return .merge(checkAppUpdate(), holdSplash())

            // 세션 복원은 버전 체크를 통과한 뒤에 시작한다 — 강제 업데이트 화면에서는 아무것도 조회하지 않는다.
            case .updateCheckResponse(.notRequired):
                return .merge(restoreSession(), observeSessionExpiration())

            case let .updateCheckResponse(.forced(storeURL)):
                // 여기서 나가는 전이는 없다. 업데이트해야만 앱을 쓸 수 있다.
                leaveSplash(for: .forceUpdate(storeURL: storeURL), &state)
                return .none

            case .splashMinimumHoldFinished:
                guard case var .launching(splash) = state else { return .none }
                guard let destination = splash.pendingDestination else {
                    splash.isMinimumHoldElapsed = true
                    state = .launching(splash)
                    return .none
                }
                state = Self.resolvedState(for: destination)
                guard case .home = state else { return .none }
                return deliverPendingInviteCode()

            case .forceUpdateConfirmTapped:
                guard case let .forceUpdate(storeURL) = state, let url = storeURL else { return .none }
                return .run { [openURL] _ in await openURL(url) }

            case let .roomCoverSaveFailed(roomID, previousCover):
                revertRoomCover(roomID: roomID, to: previousCover, &state)
                return .none

            // MARK: - 초대 링크

            // 유니버설 링크로 열렸다 — 초대 링크면 입장을 잇고, 아니면 아무것도 하지 않는다.
            case let .inviteLinkOpened(url):
                guard let code = InviteLink.code(from: url) else { return .none }
                // 로그인 전이면 보관한다 — 홈에 도달하는 시점(프로필 조회 성공·프로필 설정 완료)이 꺼내 쓴다.
                guard let profile = state.profile else {
                    return .run { [pendingInviteCode] _ in pendingInviteCode.store(code) }
                }
                // 어느 화면에 있었든 홈으로 돌아가 입장을 맡긴다 — 성공 반영도 실패 얼럿도 홈의 것을 쓴다.
                if state.screenID != .home {
                    state = .home(HomeScreen(profile: profile))
                }
                return .send(.home(.inviteCodeReceived(code)))

            case .sessionRestored(.restored):
                return fetchMyProfile()

            case .sessionRestored(.signedOut):
                leaveSplash(for: .login, &state)
                return .none

            case .sessionExpired:
                guard state.screenID != .login else { return .none }
                if case .launching = state {
                    leaveSplash(for: .login, &state)
                } else {
                    state = .login(LoginFeature.State())
                }
                return .cancel(id: CancelID.profile)

            // 늦게 도착한 프로필 응답이 이미 정해진 목적지를 덮지 못하게 하는 방어선 —
            // 강제 업데이트 화면, 그리고 세션 만료가 스플래시에 맡아둔 login이 여기 걸린다.
            case let .profileResponse(.success(profile)):
                guard case let .launching(splash) = state, splash.pendingDestination == nil
                else { return .none }
                leaveSplash(
                    for: profile.isProfileCompleted ? .home(profile) : .profileSetup,
                    &state
                )
                // 스플래시가 홈을 맡아 두기만 했으면 아직 꺼내지 않는다 — 실제로 도달한 순간에 꺼낸다.
                guard case .home = state else { return .none }
                return deliverPendingInviteCode()

            case .profileResponse(.failure):
                guard case let .launching(splash) = state, splash.pendingDestination == nil
                else { return .none }
                // 미로그인(401)도 조회 실패도 결론은 같다 — 로그인부터 다시.
                leaveSplash(for: .login, &state)
                return .none

            case .login(.delegate(.loginSucceeded)):
                // 프로필 조회 동안만 잠깐 거치는 재진입이라 최소 노출을 다시 적용하지 않는다.
                state = .launching(SplashScreen(isMinimumHoldElapsed: true))
                // 여기서 한번 sync 처리.
                return .merge(
                    fetchMyProfile(),
                    .run { [pushTokenSynchronizer] _ in await pushTokenSynchronizer.sync() }
                )

            case let .profileSetup(.delegate(.setupCompleted(profile))):
                state = .home(HomeScreen(profile: profile))
                return deliverPendingInviteCode()

            // MARK: - 홈 delegate

            // 홈이 알리는 화면 전환 요청 — Feature끼리는 서로를 모르므로 조립은 App이 한다 (규칙 3).
            case .home(.delegate(.settingsTapped)):
                guard case let .home(screen) = state else { return .none }
                state = .setting(SettingScreen(profile: screen.profile, homeCards: screen.home.cards))
                return .none

            // 목록에서 고른 방, 방금 만든 방, 초대 코드로 들어간 방 모두 상세로 들어간다.
            case let .home(.delegate(.roomSelected(card))),
                 let .home(.delegate(.roomCreated(card))),
                 let .home(.delegate(.roomJoined(card))):
                guard case let .home(screen) = state else { return .none }
                state = .roomDetail(
                    RoomDetailScreen(profile: screen.profile, room: card.room, homeCards: screen.home.cards)
                )
                return .none

            case let .openRoomRequested(room):
                // 촬영 중에는 화면을 뺏지 않는다 — 찍고 있던 것이 사라진다.
                // 로그인 전 화면에는 프로필이 없어 만들 화면도 없다.
                guard state.screenID != .camera, let profile = state.currentProfile else { return .none }
                state = .roomDetail(RoomDetailScreen(profile: profile, room: room))
                return .none

            // 진입 버튼이 방·필터·권한을 모두 갖춘 뒤에만 오는 요청이라 여기서 바로 띄운다.
            case let .home(.delegate(.cameraRequested(entry))):
                guard case let .home(screen) = state else { return .none }
                state = .camera(
                    CameraScreen(
                        profile: screen.profile,
                        entry: entry,
                        origin: .home,
                        homeCards: screen.home.cards
                    )
                )
                return .none

            // MARK: - 방 상세 delegate

            case .roomDetail(.delegate(.closeTapped)):
                guard case let .roomDetail(screen) = state else { return .none }
                // 홈 State를 새로 만들어 목록을 다시 조회한다 — 방에서 사진을 찍고 나왔을 수 있다.
                // 직전 목록을 시딩해 재조회가 끝나기 전에도 전환 중 홈이 비어 보이지 않게 한다.
                state = .home(HomeScreen(profile: screen.profile, cards: screen.homeCards))
                return .none

            case .roomDetail(.delegate(.settingsTapped)):
                guard case let .roomDetail(screen) = state else { return .none }
                state = .roomSettings(
                    RoomSettingsScreen(
                        profile: screen.profile,
                        room: screen.roomDetail.room,
                        homeCards: screen.homeCards,
                        // 커버 미리보기가 그릴 인원수. 상세 조회 전이면 홈 카드 값으로 메운다.
                        memberCount: screen.roomDetail.detail?.members.count
                            ?? screen.homeCards[id: screen.roomDetail.room.id]?.memberCount
                            ?? 0
                    )
                )
                return .none

            // 방 상세에서 채팅 버튼 — 방 채팅 화면으로 들어간다.
            case .roomDetail(.delegate(.chatTapped)):
                guard case let .roomDetail(screen) = state else { return .none }
                state = .chat(
                    ChatScreen(
                        profile: screen.profile,
                        room: screen.roomDetail.room,
                        homeCards: screen.homeCards
                    )
                )
                return .none

            case let .roomDetail(.delegate(.cameraRequested(entry))):
                guard case let .roomDetail(screen) = state else { return .none }
                state = .camera(
                    CameraScreen(
                        profile: screen.profile,
                        entry: entry,
                        origin: .roomDetail(screen.roomDetail.room),
                        homeCards: screen.homeCards
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
                        initialPhotoID: photoID,
                        homeCards: screen.homeCards
                    )
                )
                return .none

            // MARK: - 사진 상세 delegate

            case .photoDetail(.delegate(.closeRequested)):
                guard case let .photoDetail(screen) = state else { return .none }
                // 방 상세를 다시 만든다 — 상세로 돌아가면 사진·리액션을 새로 조회해 최신 상태를 그린다.
                state = .roomDetail(
                    RoomDetailScreen(profile: screen.profile, room: screen.room, homeCards: screen.homeCards)
                )
                return .none

            // MARK: - 채팅 delegate

            case .chat(.delegate(.closeRequested)):
                guard case let .chat(screen) = state else { return .none }
                // 방 상세를 다시 만든다 — 돌아가면 사진·리액션을 새로 조회해 최신 상태를 그린다.
                state = .roomDetail(
                    RoomDetailScreen(profile: screen.profile, room: screen.room, homeCards: screen.homeCards)
                )
                return .none

            // MARK: - 카메라 delegate

            // 들어온 화면을 새로 만들어 되돌린다 — 촬영으로 남은 장수·사진이 바뀌었을 수 있어 다시 조회된다.
            case .camera(.camera(.delegate(.closeRequested))):
                guard case let .camera(screen) = state else { return .none }
                switch screen.origin {
                case .home:
                    state = .home(HomeScreen(profile: screen.profile, cards: screen.homeCards))
                case let .roomDetail(room):
                    state = .roomDetail(
                        RoomDetailScreen(profile: screen.profile, room: room, homeCards: screen.homeCards)
                    )
                }
                return .none

            // 촬영본이 방에 올라갔다 — 찍은 방의 상세로 들어가고, 방금 넣은 사진을 강조하라고 알린다.
            // 방을 못 찾으면(있을 수 없지만) 닫기와 같은 길로 되돌린다.
            case let .camera(.camera(.delegate(.captureFinished(roomID)))):
                guard case let .camera(screen) = state else { return .none }
                guard let room = screen.shotRoom(id: roomID) else {
                    return .send(.camera(.camera(.delegate(.closeRequested))))
                }
                state = .roomDetail(
                    RoomDetailScreen(
                        profile: screen.profile,
                        room: room,
                        homeCards: screen.homeCards,
                        highlightsNewestPhoto: true
                    )
                )
                return .none

            // MARK: - 방 설정 delegate

            case .roomSettings(.delegate(.closeTapped)):
                guard case let .roomSettings(screen) = state else { return .none }
                // 맡아둔 room의 제목은 설정 진입 시점 값이라, 설정 화면이 들고 있는 최신 제목으로 고쳐서 넘긴다.
                // 상세 첫 프레임부터 새 이름이 보이고, 재조회가 실패해도 옛 이름으로 되돌아가지 않는다.
                state = .roomDetail(RoomDetailScreen(
                    profile: screen.profile,
                    room: screen.room.renamed(to: screen.settings.title),
                    homeCards: screen.homeCards
                ))
                return .none

            case .roomSettings(.delegate(.coverEditRequested)):
                openCoverEdit(&state)
                return .none

            // MARK: - 커버 수정 delegate

            case .roomCoverEdit(.delegate(.closeTapped)):
                closeCoverEdit(&state)
                return .none

            // MARK: - 설정 delegate

            case .setting(.delegate(.backRequested)):
                guard case let .setting(screen) = state else { return .none }
                state = .home(HomeScreen(profile: screen.profile, cards: screen.homeCards))
                return .none

            case .setting(.delegate(.editProfileRequested)):
                guard case let .setting(screen) = state else { return .none }
                state = .profileEdit(
                    ProfileEditScreen(profile: screen.profile, homeCards: screen.homeCards)
                )
                return .none

            case .setting(.delegate(.signedOut)), .setting(.delegate(.accountDeleted)):
                state = .login(LoginFeature.State())
                return .none

            // MARK: - 프로필 편집 delegate

            case let .profileEdit(.delegate(.editCompleted(profile))):
                // 설정 State를 새로 만들어 헤더가 바뀐 닉네임을 다시 읽게 한다
                // (`onAppear`가 `profile == nil`일 때만 조회한다).
                guard case let .profileEdit(screen) = state else { return .none }
                state = .setting(SettingScreen(profile: profile, homeCards: screen.homeCards))
                return .none

            case .profileEdit(.delegate(.cancelled)):
                guard case let .profileEdit(screen) = state else { return .none }
                state = .setting(SettingScreen(profile: screen.profile, homeCards: screen.homeCards))
                return .none

            // MARK: - 인터랙티브 pop

            case .popGestureCompleted:
                return popCurrentScreen(&state)

            case .login, .profileSetup, .home, .roomDetail, .roomSettings, .roomCoverEdit,
                 .photoDetail, .chat, .setting, .profileEdit, .camera:
                return .none
            }
        }
    }
}
