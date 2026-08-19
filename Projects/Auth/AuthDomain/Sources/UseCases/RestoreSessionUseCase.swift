import Dependencies
import DependenciesMacros

@DependencyClient
public struct RestoreSessionUseCase: Sendable {
    public var run: @Sendable () -> SessionRestoration = { .signedOut }
}

extension RestoreSessionUseCase: TestDependencyKey {

    /// 앱 시작 직후, 어떤 인증 요청보다도 먼저 한 번 실행되는 것을 전제로 한다.
    public static func live(
        tokenStore: any TokenStore,
        launchState: any LaunchStateStore
    ) -> RestoreSessionUseCase {
        RestoreSessionUseCase(run: {
            guard launchState.hasLaunchedBefore else {
                try? tokenStore.clear() // 재설치 직후 — 이전 설치가 남긴 키체인 항목을 버린다
                launchState.markLaunched()
                return .signedOut
            }
            return tokenStore.loadRefreshToken() == nil ? .signedOut : .restored
        })
    }

    public static let testValue = RestoreSessionUseCase()

    public static let previewValue = RestoreSessionUseCase(run: { .restored })
}

public extension DependencyValues {
    var restoreSessionUseCase: RestoreSessionUseCase {
        get { self[RestoreSessionUseCase.self] }
        set { self[RestoreSessionUseCase.self] = newValue }
    }
}
