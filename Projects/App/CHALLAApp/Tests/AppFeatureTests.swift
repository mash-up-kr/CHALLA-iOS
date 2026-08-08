@testable import CHALLAApp
import ComposableArchitecture
import Foundation
import ProfileSetupFeature
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
}

@MainActor
@Suite("AppFeature — 화면 전이")
struct AppFeatureTests {

    private static func store(
        initialState: AppFeature.State
    ) -> TestStoreOf<AppFeature> {
        TestStore(initialState: initialState) {
            AppFeature()
        }
    }

    // MARK: - 설정 진입·이탈

    @Test("홈에서 설정 버튼을 누르면 설정 화면으로 간다")
    func opensSettingFromHome() async {
        let store = Self.store(initialState: .home(Fixture.profile))

        await store.send(.settingButtonTapped) {
            $0 = .setting(AppFeature.SettingScreen(profile: Fixture.profile))
        }
    }

    @Test("설정에서 뒤로가면 프로필을 다시 조회하지 않고 홈으로 돌아간다")
    func returnsHomeFromSetting() async {
        let store = Self.store(
            initialState: .setting(AppFeature.SettingScreen(profile: Fixture.profile))
        )

        await store.send(.setting(.delegate(.backRequested))) {
            $0 = .home(Fixture.profile)
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

    @Test("추가된 두 화면도 screenID로 구분된다 — VoiceOver 화면 전환 알림에 쓴다")
    func screenIDCoversNewScreens() {
        let setting = AppFeature.State.setting(AppFeature.SettingScreen(profile: Fixture.profile))
        let edit = AppFeature.State.profileEdit(
            AppFeature.ProfileEditScreen(profile: Fixture.profile)
        )

        #expect(setting.screenID == .setting)
        #expect(edit.screenID == .profileEdit)
    }
}
