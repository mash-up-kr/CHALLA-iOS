@testable import CHALLAApp
import AppDomain
import AuthDomain
import ComposableArchitecture
import Foundation
import Testing
import UserDomain

/// `@MainActor` 밖에 둔다 — `withDependencies`에 넘기는 `@Sendable` 클로저가 액터 경계를 넘어 읽는다.
private enum Fixture {
    static let profile = UserProfile(
        id: 1,
        nickname: "찰나",
        imageURL: URL(string: "https://cdn.example.com/me.jpg")
    )
    static let appStore = URL(string: "https://apps.apple.com/kr/app/id0000000000")
}

@MainActor
@Suite("AppFeature — 버전 체크·강제 업데이트")
struct AppForceUpdateTests {

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

    @Test("버전 체크를 통과하면 프로필 조회로 이어진다")
    func proceedsToProfileAfterUpdateCheckPasses() async {
        let channel = SessionExpirationChannel()
        let clock = TestClock()
        let store = TestStore(initialState: AppFeature.State.launching(.init())) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.checkAppUpdateUseCase.run = { .notRequired }
            $0.restoreSessionUseCase = RestoreSessionUseCase(run: { .restored })
            $0.fetchMyProfileUseCase = FetchMyProfileUseCase(run: { Fixture.profile })
            $0.sessionExpirationChannel = channel
        }

        await store.send(.task)
        await store.receive(\.updateCheckResponse, .notRequired)
        await store.receive(\.sessionRestored, .restored)
        await store.receive(\.profileResponse.success, Fixture.profile) {
            $0 = .launching(.init(pendingDestination: .home(Fixture.profile)))
        }

        await clock.advance(by: AppFeature.splashMinimumHold)
        await store.receive(\.splashMinimumHoldFinished) {
            $0 = .home(AppFeature.HomeScreen(profile: Fixture.profile))
        }

        channel.finish()
        await store.finish()
    }

    @Test("강제 업데이트면 스토어 주소를 들고 화면이 막히고 프로필 조회를 시작하지 않는다")
    func blocksOnForcedUpdateWithoutFetchingProfile() async {
        // fetchMyProfileUseCase는 일부러 주입하지 않는다 — 호출되면 unimplemented로 실패한다.
        let clock = TestClock()
        let store = TestStore(initialState: AppFeature.State.launching(.init())) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.checkAppUpdateUseCase.run = { .forced(storeURL: Fixture.appStore) }
        }

        await store.send(.task)
        // 강제 업데이트도 스플래시 최소 노출은 지킨다 — 목적지만 맡아 둔다.
        await store.receive(\.updateCheckResponse, .forced(storeURL: Fixture.appStore)) {
            $0 = .launching(.init(pendingDestination: .forceUpdate(storeURL: Fixture.appStore)))
        }

        await clock.advance(by: AppFeature.splashMinimumHold)
        await store.receive(\.splashMinimumHoldFinished) {
            $0 = .forceUpdate(storeURL: Fixture.appStore)
        }
        await store.finish()
    }

    @Test("이미 화면에 진입한 뒤 task가 다시 와도 버전 체크를 반복하지 않는다")
    func ignoresTaskAfterLeavingLaunching() async {
        // checkAppUpdateUseCase를 주입하지 않는다 — 가드가 뚫리면 unimplemented로 실패한다.
        let store = Self.store(initialState: .home(AppFeature.HomeScreen(profile: Fixture.profile)))

        await store.send(.task)
        await store.finish()
    }

    @Test("버전 체크 실패는 앱을 막지 않는다 — 통과로 접고 프로필 조회를 진행한다")
    func failsOpenWhenUpdateCheckThrows() async {
        struct VersionCheckError: Error {}
        let channel = SessionExpirationChannel()
        let clock = TestClock()
        let store = TestStore(initialState: AppFeature.State.launching(.init())) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.checkAppUpdateUseCase.run = { throw VersionCheckError() }
            $0.restoreSessionUseCase = RestoreSessionUseCase(run: { .restored })
            $0.fetchMyProfileUseCase = FetchMyProfileUseCase(run: { Fixture.profile })
            $0.sessionExpirationChannel = channel
        }

        await store.send(.task)
        await store.receive(\.updateCheckResponse, .notRequired)
        await store.receive(\.sessionRestored, .restored)
        await store.receive(\.profileResponse.success, Fixture.profile) {
            $0 = .launching(.init(pendingDestination: .home(Fixture.profile)))
        }

        await clock.advance(by: AppFeature.splashMinimumHold)
        await store.receive(\.splashMinimumHoldFinished) {
            $0 = .home(AppFeature.HomeScreen(profile: Fixture.profile))
        }

        channel.finish()
        await store.finish()
    }

    @Test("'확인'을 누르면 응답에 실려 온 스토어 주소를 열고 화면은 그대로 막혀 있다")
    func opensAppStoreOnConfirmAndStaysBlocked() async throws {
        let appStore = try #require(Fixture.appStore)
        let opened = LockIsolated<[URL]>([])

        let store = TestStore(initialState: AppFeature.State.forceUpdate(storeURL: appStore)) {
            AppFeature()
        } withDependencies: {
            $0.openURL = OpenURLEffect { url in
                opened.withValue { $0.append(url) }
                return true
            }
        }

        await store.send(.forceUpdateConfirmTapped)
        await store.finish()

        #expect(opened.value == [appStore])
        #expect(store.state.screenID == .forceUpdate)
    }

    @Test("스토어 주소가 없으면 아무 것도 열지 않는다")
    func doesNothingWithoutAppStoreURL() async {
        let store = TestStore(initialState: AppFeature.State.forceUpdate(storeURL: nil)) {
            AppFeature()
        } withDependencies: {
            $0.openURL = OpenURLEffect { _ in
                Issue.record("주소가 없으면 열기를 시도하면 안 된다")
                return false
            }
        }

        await store.send(.forceUpdateConfirmTapped)
        await store.finish()
    }

    @Test("강제 업데이트 상태에서는 늦게 온 프로필 응답이 화면을 바꾸지 못한다")
    func ignoresLateProfileResponseWhileBlocked() async {
        let store = Self.store(initialState: .forceUpdate(storeURL: nil))

        await store.send(.profileResponse(.success(Fixture.profile)))
        await store.send(.profileResponse(.failure(.network)))

        #expect(store.state.screenID == .forceUpdate)
    }

    @Test("스플래시가 강제 업데이트를 맡아둔 뒤에는 늦게 온 프로필 응답이 목적지를 덮지 못한다")
    func keepsPendingForceUpdateOverLateProfileResponse() async {
        let store = Self.store(
            initialState: .launching(
                .init(pendingDestination: .forceUpdate(storeURL: Fixture.appStore))
            )
        )

        await store.send(.profileResponse(.success(Fixture.profile)))
    }
}
