@testable import CHALLAApp
import AppDomain
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
}

@MainActor
@Suite("AppFeature — 스플래시 최소 노출")
struct AppSplashTests {

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

    @Test("최소 노출이 끝나도 준비된 화면이 없으면 스플래시를 유지한다")
    func staysOnSplashWhenNothingReady() async {
        let store = Self.store(initialState: .launching(.init()))

        await store.send(.splashMinimumHoldFinished) {
            $0 = .launching(.init(isMinimumHoldElapsed: true))
        }
    }

    @Test("스플래시 노출 중 세션이 만료되면 로그인을 맡아 뒀다가 노출이 끝난 뒤 전이한다")
    func holdsLoginOnSessionExpirationDuringSplash() async {
        let store = Self.store(initialState: .launching(.init()))

        await store.send(.sessionExpired) {
            $0 = .launching(.init(pendingDestination: .login))
        }
        await store.send(.splashMinimumHoldFinished) {
            $0 = .login(.init())
        }
    }

    @Test("스플래시가 홈을 맡아둔 뒤 세션이 만료되면 로그인이 이긴다")
    func sessionExpirationOverridesPendingHome() async {
        let store = Self.store(
            initialState: .launching(.init(pendingDestination: .home(Fixture.profile)))
        )

        await store.send(.sessionExpired) {
            $0 = .launching(.init(pendingDestination: .login))
        }
    }

    @Test("스플래시가 로그인을 맡아둔 뒤에는 늦게 온 프로필 응답이 목적지를 덮지 못한다")
    func keepsPendingLoginOverLateProfileResponse() async {
        let store = Self.store(
            initialState: .launching(.init(pendingDestination: .login))
        )

        await store.send(.profileResponse(.success(Fixture.profile)))
        await store.send(.profileResponse(.failure(.network)))
    }
}
