@testable import SettingFeature
import ComposableArchitecture
import SettingDomain
import Testing

@MainActor
struct AccountFeatureTests {

    private static func store(
        drawer: AccountFeature.Drawer? = nil,
        isProcessing: Bool = false,
        prepare: (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<AccountFeature> {
        var state = AccountFeature.State(profile: nil)
        state.drawer = drawer
        state.isProcessing = isProcessing

        return TestStore(initialState: state) {
            AccountFeature()
        } withDependencies: {
            prepare(&$0)
        }
    }

    private static func failureAlert(
        title: String,
        error: SettingError
    ) -> AlertState<AccountFeature.Action.Alert> {
        AlertState {
            TextState(title)
        } actions: {
            ButtonState(role: .cancel) { TextState("확인") }
        } message: {
            TextState(error.userMessage)
        }
    }

    // MARK: - 드로어 열고 닫기

    @Test("로그아웃 행을 누르면 확인 드로어가 뜬다")
    func opensSignOutDrawer() async {
        let store = Self.store()

        await store.send(.view(.signOutRowTapped)) {
            $0.drawer = .signOutConfirmation
        }
    }

    @Test("탈퇴하기를 누르면 확인 드로어가 뜬다")
    func opensDeleteDrawer() async {
        let store = Self.store()

        await store.send(.view(.deleteAccountButtonTapped)) {
            $0.drawer = .deleteConfirmation
        }
    }

    @Test(
        "확인 드로어를 내리면 그냥 닫힌다 — 부모에게 알릴 것이 없다",
        arguments: [AccountFeature.Drawer.signOutConfirmation, .deleteConfirmation]
    )
    func dismissesConfirmationDrawer(drawer: AccountFeature.Drawer) async {
        let store = Self.store(drawer: drawer)

        await store.send(.view(.drawerDismissed)) {
            $0.drawer = nil
        }
    }

    @Test("확인 드로어는 딤 탭으로 내릴 수 있다")
    func confirmationDrawerIsDismissable() {
        var state = AccountFeature.State(profile: nil)
        state.drawer = .deleteConfirmation

        #expect(state.isDrawerDismissable)
    }

    @Test("완료 드로어와 처리 중 드로어는 내릴 수 없다")
    func lockedDrawers() {
        var completed = AccountFeature.State(profile: nil)
        completed.drawer = .deleteCompleted
        #expect(completed.isDrawerDismissable == false)

        var processing = AccountFeature.State(profile: nil)
        processing.drawer = .deleteConfirmation
        processing.isProcessing = true
        #expect(processing.isDrawerDismissable == false)
    }

    // MARK: - 로그아웃

    @Test("로그아웃에 성공하면 드로어를 닫고 부모에게 알린다")
    func signOutSucceeds() async {
        let store = Self.store(drawer: .signOutConfirmation) {
            $0.signOutUseCase = SignOutUseCase(run: {})
        }

        await store.send(.view(.signOutConfirmed)) {
            // 드로어는 그대로 두고 버튼만 잠근다.
            $0.isProcessing = true
        }
        await store.receive(\.signOutSucceeded) {
            $0.isProcessing = false
            $0.drawer = nil
        }
        await store.receive(\.delegate.signedOut)
    }

    @Test("로그아웃에 실패하면 드로어를 닫고 얼럿을 띄운다")
    func signOutFails() async {
        let store = Self.store(drawer: .signOutConfirmation) {
            $0.signOutUseCase = SignOutUseCase(run: { throw SettingError.network })
        }

        await store.send(.view(.signOutConfirmed)) { $0.isProcessing = true }
        await store.receive(\.signOutFailed, .network) {
            $0.isProcessing = false
            $0.drawer = nil
            $0.alert = Self.failureAlert(title: "로그아웃하지 못했어요", error: .network)
        }
    }

    @Test("SettingError가 아닌 오류도 얼럿까지 도달한다 — 화면이 조용히 멈추면 안 된다")
    func normalizesUnknownSignOutError() async {
        struct Unexpected: Error {}

        let store = Self.store(drawer: .signOutConfirmation) {
            $0.signOutUseCase = SignOutUseCase(run: { throw Unexpected() })
        }

        await store.send(.view(.signOutConfirmed)) { $0.isProcessing = true }
        await store.receive(\.signOutFailed, .unknown) {
            $0.isProcessing = false
            $0.drawer = nil
            $0.alert = Self.failureAlert(title: "로그아웃하지 못했어요", error: .unknown)
        }
    }

    // MARK: - 회원 탈퇴

    @Test("탈퇴에 성공하면 완료 드로어로 바꾼다 — 부모에게는 아직 알리지 않는다")
    func deleteSucceeds() async {
        let store = Self.store(drawer: .deleteConfirmation) {
            $0.deleteAccountUseCase = DeleteAccountUseCase(run: {})
        }

        await store.send(.view(.deleteConfirmed)) { $0.isProcessing = true }
        await store.receive(\.accountDeletionSucceeded) {
            $0.isProcessing = false
            $0.drawer = .deleteCompleted
        }
    }

    @Test("완료를 확인하면 드로어를 닫고 부모에게 알린다")
    func confirmsDeletionCompletion() async {
        let store = Self.store(drawer: .deleteCompleted)

        await store.send(.view(.deleteCompletionConfirmed)) { $0.drawer = nil }
        await store.receive(\.delegate.accountDeleted)
    }

    @Test("완료 드로어가 새어 나온 dismiss로 닫혀도 부모에게 알린다 — 없는 계정 화면에 남으면 안 된다")
    func treatsCompletedDrawerDismissAsConfirmation() async {
        let store = Self.store(drawer: .deleteCompleted)

        await store.send(.view(.drawerDismissed)) { $0.drawer = nil }
        await store.receive(\.delegate.accountDeleted)
    }

    @Test("탈퇴에 실패하면 드로어를 닫고 얼럿을 띄운다")
    func deleteFails() async {
        let store = Self.store(drawer: .deleteConfirmation) {
            $0.deleteAccountUseCase = DeleteAccountUseCase(run: { throw SettingError.unknown })
        }

        await store.send(.view(.deleteConfirmed)) { $0.isProcessing = true }
        await store.receive(\.accountDeletionFailed, .unknown) {
            $0.isProcessing = false
            $0.drawer = nil
            $0.alert = Self.failureAlert(title: "탈퇴하지 못했어요", error: .unknown)
        }
    }

    // MARK: - 처리 중 가드

    @Test("로그아웃 처리 중에는 중복 실행도 뒤로가기도 막고, 응답은 그대로 도착한다")
    func guardsWhileSigningOut() async {
        let gate = EffectGate()
        let callCount = LockIsolated(0)
        let dismissCount = LockIsolated(0)

        let store = Self.store(drawer: .signOutConfirmation) {
            $0.signOutUseCase = SignOutUseCase(run: {
                callCount.withValue { $0 += 1 }
                await gate.wait()
            })
            $0.dismiss = DismissEffect { dismissCount.withValue { $0 += 1 } }
        }

        await store.send(.view(.signOutConfirmed)) { $0.isProcessing = true }

        // 중복 확인 · 드로어 다시 열기 · 뒤로가기 — 모두 무시된다.
        await store.send(.view(.signOutConfirmed))
        await store.send(.view(.signOutRowTapped))
        await store.send(.view(.backButtonTapped))

        gate.open()

        // 뒤로가기가 막혀 이펙트가 취소되지 않았다 — 성공도 실패도 오지 않던 회귀 지점이다.
        await store.receive(\.signOutSucceeded) {
            $0.isProcessing = false
            $0.drawer = nil
        }
        await store.receive(\.delegate.signedOut)

        #expect(callCount.value == 1)
        #expect(dismissCount.value == 0)
    }

    @Test("탈퇴 처리 중에는 중복 실행도 뒤로가기도 막고, 응답은 그대로 도착한다")
    func guardsWhileDeleting() async {
        let gate = EffectGate()
        let callCount = LockIsolated(0)
        let dismissCount = LockIsolated(0)

        let store = Self.store(drawer: .deleteConfirmation) {
            $0.deleteAccountUseCase = DeleteAccountUseCase(run: {
                callCount.withValue { $0 += 1 }
                await gate.wait()
            })
            $0.dismiss = DismissEffect { dismissCount.withValue { $0 += 1 } }
        }

        await store.send(.view(.deleteConfirmed)) { $0.isProcessing = true }

        // 중복 확인 · 드로어 다시 열기 · 뒤로가기 — 모두 무시된다.
        await store.send(.view(.deleteConfirmed))
        await store.send(.view(.deleteAccountButtonTapped))
        await store.send(.view(.backButtonTapped))

        gate.open()

        await store.receive(\.accountDeletionSucceeded) {
            $0.isProcessing = false
            $0.drawer = .deleteCompleted
        }

        #expect(callCount.value == 1)
        #expect(dismissCount.value == 0)
    }

    // MARK: - 뒤로가기

    @Test("처리 중이 아니면 뒤로가기로 스스로 스택에서 빠진다")
    func dismissesOnBack() async {
        let dismissCount = LockIsolated(0)
        let store = Self.store {
            $0.dismiss = DismissEffect { dismissCount.withValue { $0 += 1 } }
        }

        await store.send(.view(.backButtonTapped))
        await store.finish()

        #expect(dismissCount.value == 1)
    }
}
