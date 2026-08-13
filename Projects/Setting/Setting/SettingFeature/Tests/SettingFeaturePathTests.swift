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
        email: "hap****@naver.com",
        avatarURL: nil
    )
    static let theme = AppTheme.blueberry
}

/// 하위 화면 스택(`path`) — 무엇이 쌓이고, 자식이 올린 delegate를 어떻게 받는가.
@MainActor
struct SettingFeaturePathTests {

    /// 이미 불러온 뒤의 상태 — 하위 화면에 무엇이 시드되는지 볼 때 쓴다.
    private static func loadedState(theme: AppTheme = Fixture.theme) -> SettingFeature.State {
        var state = SettingFeature.State()
        state.profile = Fixture.profile
        state.theme = theme
        return state
    }

    // MARK: - push

    @Test("테마 행을 누르면 현재 테마를 시드해 테마 화면을 쌓는다")
    func pushesThemeScreen() async {
        let store = TestStore(initialState: Self.loadedState(theme: .blueberry)) {
            SettingFeature()
        }

        await store.send(.view(.themeRowTapped)) {
            $0.path.append(.theme(ThemeFeature.State(selectedTheme: .blueberry)))
        }
    }

    @Test("알림 행을 누르면 현재 테마를 시드해 알림 화면을 쌓는다")
    func pushesNotificationScreen() async {
        let store = TestStore(initialState: Self.loadedState(theme: .cider)) {
            SettingFeature()
        }

        await store.send(.view(.notificationRowTapped)) {
            $0.path.append(.notification(NotificationSettingFeature.State(theme: .cider)))
        }
    }

    @Test("계정 관리 행을 누르면 프로필을 시드해 계정 화면을 쌓는다")
    func pushesAccountScreen() async {
        let store = TestStore(initialState: Self.loadedState()) {
            SettingFeature()
        }

        await store.send(.view(.accountRowTapped)) {
            $0.path.append(.account(AccountFeature.State(profile: Fixture.profile)))
        }
    }

    @Test("테마를 아직 읽지 못했으면 기본 테마를 시드한다 — 하위 화면이 빈 값을 받으면 안 된다")
    func seedsDefaultThemeBeforeLoading() async {
        let store = TestStore(initialState: SettingFeature.State()) {
            SettingFeature()
        }

        await store.send(.view(.themeRowTapped)) {
            $0.path.append(.theme(ThemeFeature.State(selectedTheme: .default)))
        }
    }

    // MARK: - 테마 화면 delegate

    @Test("테마 화면에서 고른 값으로 표시값을 갈아끼우고 저장한다")
    func savesThemeSelectedByChild() async {
        let saved = LockIsolated<[AppTheme]>([])
        let store = TestStore(initialState: Self.loadedState(theme: .blueberry)) {
            SettingFeature()
        } withDependencies: {
            $0.selectThemeUseCase = SelectThemeUseCase(run: { theme in
                saved.withValue { $0.append(theme) }
            })
        }

        await store.send(.view(.themeRowTapped)) {
            $0.path.append(.theme(ThemeFeature.State(selectedTheme: .blueberry)))
        }
        await store.send(.path(.element(id: 0, action: .theme(.view(.themeTapped(.orange)))))) {
            $0.path[id: 0, case: \.theme]?.selectedTheme = .orange
        }
        // 재조회 없이 표시값만 갈아끼운다.
        await store.receive(\.path[id: 0].theme.delegate.themeChanged, .orange) {
            $0.theme = .orange
        }
        await store.finish()

        #expect(store.state.themeDisplayName == "오렌지")
        // 저장은 부모가 한다 — 테마 화면이 pop돼도 이펙트가 취소되지 않아야 한다.
        #expect(saved.value == [.orange])
    }

    @Test("테마 화면이 스택에서 빠진 뒤에도 고른 값이 남는다")
    func keepsThemeAfterChildPops() async {
        var state = Self.loadedState()
        state.path.append(.theme(ThemeFeature.State(selectedTheme: .blueberry)))

        let store = TestStore(initialState: state) {
            SettingFeature()
        } withDependencies: {
            $0.selectThemeUseCase = SelectThemeUseCase(run: { _ in })
        }

        await store.send(.path(.element(id: 0, action: .theme(.delegate(.themeChanged(.raspberry)))))) {
            $0.theme = .raspberry
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
        var state = loadedState()
        state.path.append(.account(AccountFeature.State(profile: Fixture.profile)))

        return TestStore(initialState: state) {
            SettingFeature()
        }
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
