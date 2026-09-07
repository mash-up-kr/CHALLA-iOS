@testable import SettingFeature
import ComposableArchitecture
import SettingDomain
import Testing

@MainActor
struct ThemeFeatureTests {

    // MARK: - 선택

    @Test("다른 테마를 고르면 체크가 옮겨간다")
    func selectsAnotherTheme() async {
        let store = TestStore(initialState: ThemeFeature.State()) {
            ThemeFeature()
        }

        await store.send(.view(.themeTapped(.blueberry))) {
            $0.$selectedTheme.withLock { $0 = .blueberry }
        }
    }

    @Test("같은 테마를 다시 고르면 남는 변화가 없다")
    func ignoresSameTheme() async {
        let store = TestStore(initialState: ThemeFeature.State()) {
            ThemeFeature()
        }

        await store.send(.view(.themeTapped(.blueberry))) {
            $0.$selectedTheme.withLock { $0 = .blueberry }
        }
        await store.send(.view(.themeTapped(.blueberry))) // 이미 그 값이라 바뀌는 게 없다
    }

    @Test("테마를 골라도 화면을 닫지 않는다 — 체크만 옮기고 머문다")
    func staysAfterSelection() async {
        let store = TestStore(initialState: ThemeFeature.State()) {
            ThemeFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect {
                Issue.record("테마를 고른 것만으로 화면이 닫히면 안 된다")
            }
        }

        await store.send(.view(.themeTapped(.raspberry))) {
            $0.$selectedTheme.withLock { $0 = .raspberry }
        }
    }

    // MARK: - 저장소 연결

    @Test("고른 값이 저장소에 남는다 — 화면을 다시 열어도 체크가 유지된다")
    func selectionPersistsToNewState() async {
        let store = TestStore(initialState: ThemeFeature.State()) {
            ThemeFeature()
        }

        await store.send(.view(.themeTapped(.acaiBowl))) {
            $0.$selectedTheme.withLock { $0 = .acaiBowl }
        }

        #expect(ThemeFeature.State().selectedTheme == .acaiBowl)
    }

    // MARK: - 뒤로가기

    @Test("뒤로가기를 누르면 스스로 스택에서 빠진다")
    func dismissesOnBack() async {
        let dismissCount = LockIsolated(0)
        let store = TestStore(initialState: ThemeFeature.State()) {
            ThemeFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { dismissCount.withValue { $0 += 1 } }
        }

        await store.send(.view(.backButtonTapped))
        await store.finish()

        #expect(dismissCount.value == 1)
    }
}
