import Foundation
import os
import AuthDomain

/// 지정한 자격증명(또는 `AuthError`)을 돌려주고, 인증에 넘어온 provider를 기록하는 `SocialLoginService` 목.
///
/// provider 전달 여부를 검증하려면 참조 시맨틱이 필요해 final class + 락으로 구성한다
/// (iOS 17 타깃이라 `OSAllocatedUnfairLock`).
final class MockSocialLoginService: SocialLoginService {

    private let result: Result<SocialCredential, AuthError>
    private let requested = OSAllocatedUnfairLock<[AuthProvider]>(initialState: [])

    init(result: Result<SocialCredential, AuthError>) {
        self.result = result
    }

    /// authenticate에 전달된 provider (호출 순서대로).
    var authenticatedProviders: [AuthProvider] { requested.withLock { $0 } }

    func authenticate(_ provider: AuthProvider) async throws -> SocialCredential {
        requested.withLock { $0.append(provider) }
        return try result.get()
    }
}
