@testable import SettingFeature
import ComposableArchitecture
import SettingDomain
import Testing

@MainActor
struct ThemeFeatureTests {

    // MARK: - 선택

    @Test("다른 테마를 고르면 체크가 옮겨가고 부모에게 알린다")
    func selectsAnotherTheme() async {
        let store = TestStore(initialState: ThemeFeature.State(selectedTheme: .lemonade)) {
            ThemeFeature()
        }

        await store.send(.view(.themeTapped(.blueberry))) {
            $0.selectedTheme = .blueberry
        }
        await store.receive(\.delegate.themeChanged, .blueberry)
    }

    @Test("같은 테마를 다시 고르면 알릴 변화가 없다")
    func ignoresSameTheme() async {
        let store = TestStore(initialState: ThemeFeature.State(selectedTheme: .blueberry)) {
            ThemeFeature()
        }

        await store.send(.view(.themeTapped(.blueberry))) // 상태 변화도 delegate도 없다
    }

    @Test("연달아 고르면 마지막 선택이 남고 고를 때마다 알린다 — 그 자리에서 다시 고를 수 있다")
    func keepsLastSelection() async {
        let store = TestStore(initialState: ThemeFeature.State(selectedTheme: .lemonade)) {
            ThemeFeature()
        }

        await store.send(.view(.themeTapped(.orange))) { $0.selectedTheme = .orange }
        await store.receive(\.delegate.themeChanged, .orange)

        await store.send(.view(.themeTapped(.cider))) { $0.selectedTheme = .cider }
        await store.receive(\.delegate.themeChanged, .cider)
    }

    @Test("테마를 골라도 화면을 닫지 않는다 — 체크만 옮기고 머문다")
    func staysAfterSelection() async {
        let store = TestStore(initialState: ThemeFeature.State(selectedTheme: .lemonade)) {
            ThemeFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect {
                Issue.record("테마를 고른 것만으로 화면이 닫히면 안 된다")
            }
        }

        await store.send(.view(.themeTapped(.raspberry))) { $0.selectedTheme = .raspberry }
        await store.receive(\.delegate.themeChanged, .raspberry)
    }

    // MARK: - 뒤로가기

    @Test("뒤로가기를 누르면 스스로 스택에서 빠진다")
    func dismissesOnBack() async {
        let dismissCount = LockIsolated(0)
        let store = TestStore(initialState: ThemeFeature.State(selectedTheme: .lemonade)) {
            ThemeFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { dismissCount.withValue { $0 += 1 } }
        }

        await store.send(.view(.backButtonTapped))
        await store.finish()

        #expect(dismissCount.value == 1)
    }
}
