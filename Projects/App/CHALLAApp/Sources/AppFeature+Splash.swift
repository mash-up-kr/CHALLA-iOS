import ComposableArchitecture
import Foundation
import LoginFeature
import ProfileSetupFeature

// MARK: - 스플래시 게이트

extension AppFeature {

    /// 스플래시 최소 노출 시간. 그 전에 준비가 끝나도 이 시간까지는 스플래시를 유지한다 (#98).
    static let splashMinimumHold: Duration = .seconds(2)

    /// 스플래시에서 다음 화면으로 나간다 — 최소 노출이 끝나기 전이면 목적지를 맡아 두고 화면은 유지한다.
    /// 스플래시가 아닌 화면에서 부르면 아무것도 하지 않는다.
    func leaveSplash(for destination: SplashDestination, _ state: inout State) {
        guard case var .launching(splash) = state else { return }
        // 강제 업데이트가 먼저 잡혔으면 늦게 온 응답이 덮지 못한다.
        guard splash.pendingDestination?.isForceUpdate != true else { return }
        if splash.isMinimumHoldElapsed {
            state = Self.resolvedState(for: destination)
        } else {
            splash.pendingDestination = destination
            state = .launching(splash)
        }
    }

    static func resolvedState(for destination: SplashDestination) -> State {
        switch destination {
        case let .forceUpdate(storeURL):
            return .forceUpdate(storeURL: storeURL)
        case .login:
            return .login(LoginFeature.State())
        case .profileSetup:
            return .profileSetup(ProfileSetupFeature.State())
        case let .home(profile):
            return .home(HomeScreen(profile: profile))
        }
    }

    func holdSplash() -> Effect<Action> {
        .run { [clock] send in
            try await clock.sleep(for: Self.splashMinimumHold)
            await send(.splashMinimumHoldFinished)
        }
        .cancellable(id: CancelID.splashHold, cancelInFlight: true)
    }
}
