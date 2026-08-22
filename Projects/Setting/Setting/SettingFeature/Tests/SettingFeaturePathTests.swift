@testable import SettingFeature
import ComposableArchitecture
import Foundation
import SettingDomain
import Testing

/// `@MainActor` 밖에 둔다 — `withDependencies`에 넘기는 `@Sendable` 클로저가
/// 액터 경계를 넘어 이 값을 읽기 때문이다.
private enum Fixture {
    static let profile = SettingProfile(
        nickname: "나는야멋쟁이토마토",
        avatarURL: nil
    )
    static let theme = AppTheme.blueberry
}

/// 하위 화면 스택(`path`) — 무엇이 쌓이고, 자식이 올린 delegate를 어떻게 받는가.
@MainActor
struct SettingFeaturePathTests {

    /// 이미 불러온 뒤의 스토어 — 하위 화면에 무엇이 시드되는지 볼 때 쓴다.
    ///
    /// 테마 시드와 스토어를 같은 저장소 컨텍스트에서 만든다 (`withThemeStorage` 주석 참고).
    private static func loadedStore(
        theme: AppTheme = Fixture.theme,
        path: (inout StackState<SettingFeature.Path.State>) -> Void = { _ in }
    ) -> TestStoreOf<SettingFeature> {
        withThemeStorage(seeding: theme) {
            var state = SettingFeature.State()
            state.profile = Fixture.profile
            path(&state.path)
            return TestStore(initialState: state) { SettingFeature() }
        }
    }

    // MARK: - 늦게 도착한 프로필

    @Test("계정 관리에 먼저 들어가 있어도 나중에 도착한 프로필이 채워진다")
    func fillsAccountProfileWhenLoadedLate() async {
        let store = TestStore(initialState: SettingFeature.State()) {
            SettingFeature()
        }

        // 조회가 끝나기 전에 계정 관리로 진입한다 — 그 화면은 스스로 조회하지 않는다.
        await store.send(.view(.accountRowTapped)) {
            $0.path.append(.account(AccountFeature.State(profile: nil)))
        }

        await store.send(.profileResponse(.success(Fixture.profile))) {
            $0.isLoading = false
            $0.profile = Fixture.profile
            $0.path[id: $0.path.ids[0]] = .account(AccountFeature.State(profile: Fixture.profile))
        }
    }

    // MARK: - push

    @Test("테마 행을 누르면 테마 화면을 쌓는다 — 시드 없이도 현재 테마가 전달된다")
    func pushesThemeScreen() async {
        let store = Self.loadedStore(theme: .blueberry)

        await store.send(.view(.themeRowTapped)) {
            $0.path.append(.theme(ThemeFeature.State()))
        }

        #expect(store.state.path[id: 0, case: \.theme]?.selectedTheme == .blueberry)
    }

    @Test("알림 행을 누르면 알림 화면을 쌓는다")
    func pushesNotificationScreen() async {
        let store = Self.loadedStore(theme: .cider)

        await store.send(.view(.notificationRowTapped)) {
            $0.path.append(.notification(NotificationSettingFeature.State()))
        }
    }

    @Test("계정 관리 행을 누르면 프로필을 시드해 계정 화면을 쌓는다")
    func pushesAccountScreen() async {
        let store = Self.loadedStore()

        await store.send(.view(.accountRowTapped)) {
            $0.path.append(.account(AccountFeature.State(profile: Fixture.profile)))
        }
    }

    @Test("고른 적이 없으면 기본 테마가 보인다")
    func showsDefaultThemeWhenNeverPicked() {
        let store = withThemeStorage {
            TestStore(initialState: SettingFeature.State()) { SettingFeature() }
        }

        #expect(store.state.theme == .default)
        #expect(store.state.themeDisplayName == "레몬에이드")
    }

    // MARK: - 테마 화면과의 연결

    @Test("테마 화면에서 고르면 설정 화면 표시값도 함께 바뀐다")
    func reflectsThemeSelectedByChild() async {
        let store = Self.loadedStore(theme: .blueberry)

        await store.send(.view(.themeRowTapped)) {
            $0.path.append(.theme(ThemeFeature.State()))
        }
        await store.send(.path(.element(id: 0, action: .theme(.view(.themeTapped(.orange)))))) {
            $0.$theme.withLock { $0 = .orange }
        }

        // delegate도 저장 이펙트도 없다. 자식이 쓴 값을 부모가 그대로 읽는다.
        #expect(store.state.themeDisplayName == "오렌지")
    }

    @Test("테마 화면이 스택에서 빠진 뒤에도 고른 값이 남는다")
    func keepsThemeAfterChildPops() async {
        let store = Self.loadedStore { $0.append(.theme(ThemeFeature.State())) }

        await store.send(.path(.element(id: 0, action: .theme(.view(.themeTapped(.raspberry)))))) {
            $0.$theme.withLock { $0 = .raspberry }
        }
        await store.send(.path(.popFrom(id: 0))) {
            $0.path.removeAll()
        }
        await store.finish()

        #expect(store.state.themeDisplayName == "라즈베리")
    }

    // MARK: - 계정 화면 delegate

    @Test("로그아웃이 끝나면 스택을 비우고 App에 올린다")
    func clearsPathOnSignOut() async {
        let store = Self.storeWithAccountPath()

        await store.send(.path(.element(id: 0, action: .account(.delegate(.signedOut))))) {
            $0.path.removeAll()
        }
        await store.receive(\.delegate, .signedOut)
    }

    @Test("탈퇴가 끝나면 스택을 비우고 App에 올린다")
    func clearsPathOnAccountDeleted() async {
        let store = Self.storeWithAccountPath()

        await store.send(.path(.element(id: 0, action: .account(.delegate(.accountDeleted))))) {
            $0.path.removeAll()
        }
        await store.receive(\.delegate, .accountDeleted)
    }

    /// 계정 화면이 이미 쌓여 있는 스토어.
    private static func storeWithAccountPath() -> TestStoreOf<SettingFeature> {
        loadedStore { $0.append(.account(AccountFeature.State(profile: Fixture.profile))) }
    }
}

/// 앱 밖으로 나가는 두 행. `SettingExternalLinks`는 주소가 아직 미확정이라 반드시 주입해서 쓴다.
@MainActor
struct SettingFeatureExternalLinkTests {

    @Test("응원하기 행은 앱스토어 리뷰 주소를 연다")
    func supportRowOpensAppStoreReview() async throws {
        let review = try #require(URL(string: "https://apps.apple.com/app/id0?action=write-review"))
        let opened = LockIsolated<[URL]>([])

        let store = TestStore(initialState: SettingFeature.State()) {
            SettingFeature()
        } withDependencies: {
            $0.settingExternalLinks = SettingExternalLinks(
                appStoreReview: { review },
                feedbackForm: { nil }
            )
            $0.openURL = OpenURLEffect { url in
                opened.withValue { $0.append(url) }
                return true
            }
        }

        await store.send(.view(.supportRowTapped))
        await store.finish()

        #expect(opened.value == [review])
    }

    @Test("피드백 행은 피드백 폼 주소를 연다")
    func feedbackRowOpensForm() async throws {
        let form = try #require(URL(string: "https://forms.gle/challa"))
        let opened = LockIsolated<[URL]>([])

        let store = TestStore(initialState: SettingFeature.State()) {
            SettingFeature()
        } withDependencies: {
            $0.settingExternalLinks = SettingExternalLinks(
                appStoreReview: { nil },
                feedbackForm: { form }
            )
            $0.openURL = OpenURLEffect { url in
                opened.withValue { $0.append(url) }
                return true
            }
        }

        await store.send(.view(.feedbackRowTapped))
        await store.finish()

        #expect(opened.value == [form])
    }

    @Test(
        "주소가 아직 없으면 아무 것도 열지 않는다 — 눌러도 조용하다",
        arguments: [
            SettingFeature.Action.ViewAction.supportRowTapped,
            .feedbackRowTapped
        ]
    )
    func doesNothingWithoutURL(action: SettingFeature.Action.ViewAction) async {
        let store = TestStore(initialState: SettingFeature.State()) {
            SettingFeature()
        } withDependencies: {
            $0.settingExternalLinks = SettingExternalLinks(
                appStoreReview: { nil },
                feedbackForm: { nil }
            )
            $0.openURL = OpenURLEffect { _ in
                Issue.record("주소가 없으면 열기를 시도하면 안 된다")
                return false
            }
        }

        await store.send(.view(action))
        await store.finish()
    }
}
