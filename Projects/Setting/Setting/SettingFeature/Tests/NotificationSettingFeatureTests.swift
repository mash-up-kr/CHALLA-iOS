@testable import SettingFeature
import ComposableArchitecture
import SettingDomain
import Testing

/// `@MainActor` 밖에 둔다 — `withDependencies`에 넘기는 `@Sendable` 클로저가 액터 경계를 넘어 읽는다.
private enum Fixture {
    static func snapshot(
        isServiceEnabled: Bool = false,
        authorization: NotificationAuthorizationStatus
    ) -> NotificationSettingsSnapshot {
        NotificationSettingsSnapshot(
            setting: NotificationSetting(isServiceEnabled: isServiceEnabled),
            authorization: authorization
        )
    }
}

@MainActor
struct NotificationSettingFeatureTests {

    private static func store(
        loading snapshot: NotificationSettingsSnapshot
    ) -> TestStoreOf<NotificationSettingFeature> {
        TestStore(initialState: NotificationSettingFeature.State(theme: .blueberry)) {
            NotificationSettingFeature()
        } withDependencies: {
            $0.loadNotificationSettingsUseCase = LoadNotificationSettingsUseCase(run: { snapshot })
        }
    }

    // MARK: - 불러오기

    @Test("화면에 들어오면 저장값과 권한을 함께 불러온다")
    func loadsOnAppear() async {
        let snapshot = Fixture.snapshot(isServiceEnabled: true, authorization: .denied)
        let store = Self.store(loading: snapshot)

        await store.send(.view(.onAppear))
        await store.receive(\.notificationSettingsLoaded, snapshot) {
            $0.isServiceNotificationEnabled = true
            $0.systemAuthorization = .denied
        }
    }

    // MARK: - 배너 노출 조건

    @Test("권한을 조회하기 전에는 배너를 띄우지 않는다 — 허용이면 곧바로 사라져 깜빡인다")
    func hidesBannerBeforeLoading() {
        let state = NotificationSettingFeature.State(theme: .blueberry)

        #expect(state.systemAuthorization == nil)
        #expect(state.showsPermissionBanner == false)
    }

    @Test(
        "허용이 아닌 권한에는 배너를 띄운다 — 사용자 눈에는 둘 다 알림이 꺼진 상태다",
        arguments: [NotificationAuthorizationStatus.denied, .notDetermined]
    )
    func showsBannerWhenNotAuthorized(authorization: NotificationAuthorizationStatus) async {
        let snapshot = Fixture.snapshot(authorization: authorization)
        let store = Self.store(loading: snapshot)

        await store.send(.view(.onAppear))
        await store.receive(\.notificationSettingsLoaded, snapshot) {
            $0.systemAuthorization = authorization
        }

        #expect(store.state.showsPermissionBanner)
    }

    @Test("권한이 허용이면 배너를 숨긴다")
    func hidesBannerWhenAuthorized() async {
        let snapshot = Fixture.snapshot(authorization: .authorized)
        let store = Self.store(loading: snapshot)

        await store.send(.view(.onAppear))
        await store.receive(\.notificationSettingsLoaded, snapshot) {
            $0.systemAuthorization = .authorized
        }

        #expect(store.state.showsPermissionBanner == false)
    }

    // MARK: - 포그라운드 복귀

    @Test("포그라운드로 돌아오면 권한을 다시 조회한다 — 설정 앱에서 켜고 오면 배너가 사라진다")
    func reloadsWhenSceneBecomesActive() async {
        let callCount = LockIsolated(0)
        let store = TestStore(initialState: NotificationSettingFeature.State(theme: .blueberry)) {
            NotificationSettingFeature()
        } withDependencies: {
            $0.loadNotificationSettingsUseCase = LoadNotificationSettingsUseCase(run: {
                let call = callCount.withValue { count -> Int in
                    count += 1
                    return count
                }
                return Fixture.snapshot(authorization: call == 1 ? .denied : .authorized)
            })
        }

        await store.send(.view(.onAppear))
        await store.receive(\.notificationSettingsLoaded, Fixture.snapshot(authorization: .denied)) {
            $0.systemAuthorization = .denied
        }
        #expect(store.state.showsPermissionBanner)

        await store.send(.view(.sceneBecameActive))
        await store.receive(\.notificationSettingsLoaded, Fixture.snapshot(authorization: .authorized)) {
            $0.systemAuthorization = .authorized
        }

        #expect(store.state.showsPermissionBanner == false)
        #expect(callCount.value == 2)
    }

    // MARK: - 토글

    @Test("토글을 켜면 상태가 즉시 바뀌고 켠 값을 저장한다")
    func savesToggleOn() async {
        let saved = LockIsolated<[Bool]>([])
        let store = TestStore(initialState: NotificationSettingFeature.State(theme: .blueberry)) {
            NotificationSettingFeature()
        } withDependencies: {
            $0.updateServiceNotificationUseCase = UpdateServiceNotificationUseCase(run: { isOn in
                saved.withValue { $0.append(isOn) }
            })
        }

        await store.send(.view(.serviceNotificationToggled(true))) {
            $0.isServiceNotificationEnabled = true
        }
        await store.finish()

        #expect(saved.value == [true])
    }

    @Test("껐다 켜면 바꾼 값이 순서대로 저장된다")
    func savesEveryToggle() async {
        let saved = LockIsolated<[Bool]>([])
        var initialState = NotificationSettingFeature.State(theme: .blueberry)
        initialState.isServiceNotificationEnabled = true

        let store = TestStore(initialState: initialState) {
            NotificationSettingFeature()
        } withDependencies: {
            $0.updateServiceNotificationUseCase = UpdateServiceNotificationUseCase(run: { isOn in
                saved.withValue { $0.append(isOn) }
            })
        }

        await store.send(.view(.serviceNotificationToggled(false))) {
            $0.isServiceNotificationEnabled = false
        }
        await store.finish()
        await store.send(.view(.serviceNotificationToggled(true))) {
            $0.isServiceNotificationEnabled = true
        }
        await store.finish()

        #expect(saved.value == [false, true])
    }

    @Test("조회가 떠 있는 동안 토글하면 늦게 끝난 조회가 방금 뒤집은 값을 되돌리지 못한다")
    func toggleCancelsInFlightLoad() async {
        let gate = EffectGate()
        let store = TestStore(initialState: NotificationSettingFeature.State(theme: .blueberry)) {
            NotificationSettingFeature()
        } withDependencies: {
            $0.loadNotificationSettingsUseCase = LoadNotificationSettingsUseCase(run: {
                await gate.wait()
                // 토글 이전의 저장값(꺼짐)을 들고 뒤늦게 돌아온다.
                return Fixture.snapshot(authorization: .authorized)
            })
            $0.updateServiceNotificationUseCase = UpdateServiceNotificationUseCase(run: { _ in })
        }

        await store.send(.view(.onAppear)) // 조회가 뜬 채로 멈춰 있다
        await store.send(.view(.serviceNotificationToggled(true))) {
            $0.isServiceNotificationEnabled = true
        }

        gate.open() // 조회가 끝나지만 이미 취소돼 액션이 오지 않는다
        await store.finish()

        #expect(store.state.isServiceNotificationEnabled)
    }

    // MARK: - 설정 앱

    @Test("배너를 누르면 설정 앱을 연다")
    func opensSystemSettings() async {
        let openCount = LockIsolated(0)
        let store = TestStore(initialState: NotificationSettingFeature.State(theme: .blueberry)) {
            NotificationSettingFeature()
        } withDependencies: {
            $0.openSystemNotificationSettingsUseCase = OpenSystemNotificationSettingsUseCase(run: {
                openCount.withValue { $0 += 1 }
            })
        }

        await store.send(.view(.permissionBannerTapped))
        await store.finish()

        #expect(openCount.value == 1)
    }

    // MARK: - 뒤로가기

    @Test("뒤로가기를 누르면 스스로 스택에서 빠진다")
    func dismissesOnBack() async {
        let dismissCount = LockIsolated(0)
        let store = TestStore(initialState: NotificationSettingFeature.State(theme: .blueberry)) {
            NotificationSettingFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { dismissCount.withValue { $0 += 1 } }
        }

        await store.send(.view(.backButtonTapped))
        await store.finish()

        #expect(dismissCount.value == 1)
    }
}
