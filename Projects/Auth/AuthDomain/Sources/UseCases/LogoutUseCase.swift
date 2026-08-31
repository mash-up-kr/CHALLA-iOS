import Dependencies
import DependenciesMacros

/// 서버 로그아웃 + 저장 토큰 삭제.
@DependencyClient
public struct LogoutUseCase: Sendable {
    public var run: @Sendable () async throws -> Void
}

extension LogoutUseCase: TestDependencyKey {

    public static func live(
        repository: any AuthRepository,
        tokenStore: any TokenStore
    ) -> LogoutUseCase {
        LogoutUseCase(run: {
            // 저장 토큰이 없으면(이미 비로그인) 서버 호출 없이 로컬 정리만 한다.
            if let refreshToken = tokenStore.loadRefreshToken() {
                do {
                    try await repository.logout(refreshToken: refreshToken)
                } catch AuthError.network {
                    throw AuthError.network // 일시적 장애 — 토큰을 남겨 같은 조작을 다시 시도하게 한다
                } catch {
                    // 서버가 세션을 거절했다(이미 만료·무효). 로컬까지 남기면 영구히 로그아웃할 수 없다.
                }
            }
            do {
                try tokenStore.clear()
            } catch {
                throw AuthError.unknown
            }
        })
    }

    public static let testValue = LogoutUseCase()

    public static let previewValue = LogoutUseCase(run: {})
}

public extension DependencyValues {
    var logoutUseCase: LogoutUseCase {
        get { self[LogoutUseCase.self] }
        set { self[LogoutUseCase.self] = newValue }
    }
}
