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
                try await repository.logout(refreshToken: refreshToken)
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
