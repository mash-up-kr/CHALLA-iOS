@testable import CHALLAApp
import AppDomain
import AuthDomain
import ComposableArchitecture
import Foundation
import HomeFeature
import NotificationDomain
import ProfileSetupFeature
import RoomDomain
import SettingFeature
import Testing
import UserDomain

/// `@MainActor` 밖에 둔다 — `withDependencies`에 넘기는 `@Sendable` 클로저가 액터 경계를 넘어 읽는다.
private enum Fixture {
    static let profile = UserProfile(
        id: 1,
        nickname: "찰나",
        imageURL: URL(string: "https://cdn.example.com/me.jpg")
    )
    static let renamedProfile = UserProfile(id: 1, nickname: "새이름", imageURL: profile.imageURL)
    static let pushToken = "fcm-token"
    static let card = RoomCard.previewShooting
    static let appStore = URL(string: "https://apps.apple.com/kr/app/id0000000000")
}

/// 로그인 성공 뒤 토큰 등록이 걸리는지만 본다.
private actor SpyPushTokenRepository: PushTokenRepository {

    private(set) var registered: [String] = []

    func register(token: String) async throws {
        registered.append(token)
    }

    func unregister(token _: String) async throws {}

    #if DEBUG
        func sendTestPush(title _: String, body _: String) async throws -> Int {
            0
        }
    #endif
}

@MainActor
@Suite("AppFeature — 화면 전이")
struct AppFeatureTests {

    /// 시계를 주입하지 않으면 프로필 재시도 대기가 `UnimplementedClock`에 걸려
    /// 이펙트 안에서 이슈가 기록되고, 병렬 실행에서 엉뚱한 테스트의 실패로 잡힌다.
    /// `TestClock`은 시간이 저절로 흐르지 않아 의도치 않은 재시도도 막는다.
    private static func store(
        initialState: AppFeature.State,
        withDependencies updates: (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<AppFeature> {
        TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = TestClock()
            updates(&$0)
        }
    }

    // MARK: - 앱 진입 분기

    @Test("저장된 세션이 있으면 프로필을 조회해 자동 로그인한다")
    func autoLoginWithStoredSession() async {
        let channel = SessionExpirationChannel()
        let store = TestStore(initialState: AppFeature.State.launching) {
            AppFeature()
        } withDependencies: {
            $0.checkAppUpdateUseCase.run = { .notRequired }
            $0.restoreSessionUseCase = RestoreSessionUseCase(run: { .restored })
            $0.fetchMyProfileUseCase = FetchMyProfileUseCase(run: { Fixture.profile })
            $0.sessionExpirationChannel = channel
        }

        await store.send(.task)
        await store.receive(\.updateCheckResponse, .notRequired)
        await store.receive(\.sessionRestored, .restored)
        await store.receive(\.profileResponse.success, Fixture.profile) {
            $0 = .home(AppFeature.HomeScreen(profile: Fixture.profile))
        }

        channel.finish()
        await store.finish()
    }

    @Test("저장된 세션이 없으면 요청을 보내지 않고 곧바로 로그인 화면으로 간다")
    func showsLoginWithoutStoredSession() async {
        let channel = SessionExpirationChannel()
        let profileRequested = LockIsolated(false)
        let store = TestStore(initialState: AppFeature.State.launching) {
            AppFeature()
        } withDependencies: {
            $0.checkAppUpdateUseCase.run = { .notRequired }
            $0.restoreSessionUseCase = RestoreSessionUseCase(run: { .signedOut })
            $0.fetchMyProfileUseCase = FetchMyProfileUseCase(run: {
                profileRequested.setValue(true)
                return Fixture.profile
            })
            $0.sessionExpirationChannel = channel
        }

        await store.send(.task)
        await store.receive(\.updateCheckResponse, .notRequired)
        await store.receive(\.sessionRestored, .signedOut) {
            $0 = .login(.init())
        }

        channel.finish()
        await store.finish()
        #expect(profileRequested.value == false)
    }

    @Test("토큰 갱신이 최종 실패하면 어느 화면에 있든 로그인으로 되돌린다")
    func resetsToLoginOnSessionExpiration() async {
        let store = Self.store(initialState: .home(AppFeature.HomeScreen(profile: Fixture.profile)))

        await store.send(.sessionExpired) {
            $0 = .login(.init())
        }
    }

    @Test("이미 로그인 화면이면 세션 만료 알림을 무시한다 (입력 중인 상태를 날리지 않는다)")
    func ignoresSessionExpirationOnLogin() async {
        let store = Self.store(initialState: .login(.init()))

        await store.send(.sessionExpired)
    }

    @Test("프로필 설정을 마쳤으면 홈으로 간다")
    func entersHomeWhenProfileCompleted() async {
        let store = Self.store(initialState: .launching)

        await store.send(.profileResponse(.success(Fixture.profile))) {
            $0 = .home(AppFeature.HomeScreen(profile: Fixture.profile))
        }
    }

    @Test("닉네임이 없으면 프로필 설정으로 보낸다")
    func entersProfileSetupWhenNicknameMissing() async {
        let incomplete = UserProfile(id: 1)
        let store = Self.store(initialState: .launching)

        await store.send(.profileResponse(.success(incomplete))) {
            $0 = .profileSetup(.init())
        }
    }

    @Test(
        "조회에 실패하면 로그인 화면으로 되돌린다",
        arguments: [UserError.unauthorized, .network, .unknown]
    )
    func resetsToLoginOnProfileFailure(error: UserError) async {
        let store = Self.store(initialState: .launching)

        await store.send(.profileResponse(.failure(error))) {
            $0 = .login(.init())
        }
    }

    @Test("로그인에 성공하면 프로필을 다시 조회하고 푸시 토큰을 재등록한다")
    func refetchesProfileAfterLogin() async {
        let repository = SpyPushTokenRepository()
        let synchronizer = PushTokenSynchronizer(
            repository: repository,
            isServiceNotificationEnabled: { true },
            currentToken: { Fixture.pushToken }
        )
        let store = TestStore(initialState: AppFeature.State.login(.init())) {
            AppFeature()
        } withDependencies: {
            $0.fetchMyProfileUseCase = FetchMyProfileUseCase(run: { Fixture.profile })
            $0.pushTokenSynchronizer = synchronizer
        }

        await store.send(.login(.delegate(.loginSucceeded))) {
            $0 = .launching
        }
        await store.receive(\.profileResponse.success, Fixture.profile) {
            $0 = .home(AppFeature.HomeScreen(profile: Fixture.profile))
        }
        await store.finish()

        #expect(await repository.registered == [Fixture.pushToken])
    }

    // MARK: - 방 상세 진입·이탈

    /// 목록에서 고르든, 방금 만들었든, 초대 코드로 들어왔든 다음 동작은 같다.
    @Test("홈이 알리는 세 경로 모두 그 방의 상세로 들어간다", arguments: [
        HomeFeature.Action.Delegate.roomSelected(Fixture.card),
        .roomCreated(Fixture.card),
        .roomJoined(Fixture.card)
    ])
    func opensRoomDetailFromHome(delegate: HomeFeature.Action.Delegate) async {
        let store = Self.store(initialState: .home(AppFeature.HomeScreen(profile: Fixture.profile)))

        await store.send(.home(.delegate(delegate))) {
            $0 = .roomDetail(
                AppFeature.RoomDetailScreen(profile: Fixture.profile, room: Fixture.card.room)
            )
        }
    }

    /// 방에서 사진을 찍고 나왔을 수 있어 홈 State를 새로 만든다 — 목록이 다시 조회된다.
    /// 직전 목록은 시딩된다 — 재조회가 끝날 때까지 전환 중 홈이 비어 보이면 안 된다.
    @Test("방 상세에서 뒤로가면 직전 목록을 시딩한 홈을 새로 만들어 돌아간다")
    func returnsHomeFromRoomDetail() async {
        let store = Self.store(
            initialState: .roomDetail(
                AppFeature.RoomDetailScreen(
                    profile: Fixture.profile,
                    room: Fixture.card.room,
                    homeCards: [Fixture.card]
                )
            )
        )

        await store.send(.roomDetail(.delegate(.closeTapped))) {
            $0 = .home(AppFeature.HomeScreen(profile: Fixture.profile, cards: [Fixture.card]))
        }
    }

    // MARK: - 설정 진입·이탈

    @Test("홈에서 설정을 누르면 설정 화면으로 간다")
    func opensSettingFromHome() async {
        let store = Self.store(initialState: .home(AppFeature.HomeScreen(profile: Fixture.profile)))

        await store.send(.home(.delegate(.settingsTapped))) {
            $0 = .setting(AppFeature.SettingScreen(profile: Fixture.profile))
        }
    }

    @Test("설정에서 뒤로가면 프로필을 다시 조회하지 않고 홈으로 돌아간다")
    func returnsHomeFromSetting() async {
        let store = Self.store(
            initialState: .setting(AppFeature.SettingScreen(profile: Fixture.profile))
        )

        await store.send(.setting(.delegate(.backRequested))) {
            $0 = .home(AppFeature.HomeScreen(profile: Fixture.profile))
        }
    }

    @Test(
        "로그아웃·탈퇴가 끝나면 로그인 화면으로 되돌린다",
        arguments: [SettingFeature.Action.Delegate.signedOut, .accountDeleted]
    )
    func resetsToLoginAfterLeavingAccount(delegate: SettingFeature.Action.Delegate) async {
        let store = Self.store(
            initialState: .setting(AppFeature.SettingScreen(profile: Fixture.profile))
        )

        await store.send(.setting(.delegate(delegate))) {
            $0 = .login(.init())
        }
    }

    // MARK: - 프로필 편집

    @Test("편집 버튼을 누르면 기존 닉네임·사진이 프리필된 편집 화면으로 간다")
    func opensProfileEditWithSeededValues() async {
        let store = Self.store(
            initialState: .setting(AppFeature.SettingScreen(profile: Fixture.profile))
        )

        await store.send(.setting(.delegate(.editProfileRequested))) {
            $0 = .profileEdit(AppFeature.ProfileEditScreen(profile: Fixture.profile))
        }

        guard case let .profileEdit(screen) = store.state else {
            Issue.record("편집 화면이 아니다")
            return
        }
        #expect(screen.edit.mode == .edit)
        #expect(screen.edit.nickname == "찰나")
        #expect(screen.edit.remoteImageURL == Fixture.profile.imageURL)
    }

    @Test("편집을 저장하면 바뀐 프로필로 설정 화면을 새로 만든다 — 헤더가 다시 조회된다")
    func rebuildsSettingAfterEdit() async {
        let store = Self.store(
            initialState: .profileEdit(AppFeature.ProfileEditScreen(profile: Fixture.profile))
        )

        await store.send(.profileEdit(.delegate(.editCompleted(Fixture.renamedProfile)))) {
            $0 = .setting(AppFeature.SettingScreen(profile: Fixture.renamedProfile))
        }

        // State가 새로 만들어져야 SettingFeature의 onAppear가 프로필을 다시 읽는다.
        guard case let .setting(screen) = store.state else {
            Issue.record("설정 화면이 아니다")
            return
        }
        #expect(screen.setting.profile == nil)
        #expect(screen.profile == Fixture.renamedProfile)
    }

    @Test("편집에서 뒤로가면 변경을 반영하지 않고 설정으로 돌아간다")
    func discardsEditOnCancel() async {
        var editScreen = AppFeature.ProfileEditScreen(profile: Fixture.profile)
        editScreen.edit.nickname = "저장 안 된 이름"
        let store = Self.store(initialState: .profileEdit(editScreen))

        await store.send(.profileEdit(.delegate(.cancelled))) {
            $0 = .setting(AppFeature.SettingScreen(profile: Fixture.profile))
        }
    }

    // MARK: - 화면 식별자

    @Test("나중에 추가된 화면들도 screenID로 구분된다 — VoiceOver 화면 전환 알림에 쓴다")
    func screenIDCoversNewScreens() {
        let setting = AppFeature.State.setting(AppFeature.SettingScreen(profile: Fixture.profile))
        let edit = AppFeature.State.profileEdit(
            AppFeature.ProfileEditScreen(profile: Fixture.profile)
        )
        let roomDetail = AppFeature.State.roomDetail(
            AppFeature.RoomDetailScreen(profile: Fixture.profile, room: Fixture.card.room)
        )

        #expect(setting.screenID == .setting)
        #expect(edit.screenID == .profileEdit)
        #expect(roomDetail.screenID == .roomDetail)
        #expect(AppFeature.State.forceUpdate(storeURL: nil).screenID == .forceUpdate)
    }
}
