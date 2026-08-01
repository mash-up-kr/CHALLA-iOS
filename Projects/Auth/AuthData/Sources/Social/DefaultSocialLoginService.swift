import AuthDomain
import Foundation

/// `SocialLoginService` 구현 — provider별 서비스로 라우팅한다.
///
/// 각 서비스는 `@MainActor`라 `await`로 자동 hop하고,
/// 경계를 넘어오는 값은 `Sendable`인 `SocialCredential`뿐이다.
public struct DefaultSocialLoginService: SocialLoginService {

    public init() {}

    public func authenticate(_ provider: AuthProvider) async throws -> SocialCredential {
        switch provider {
        case .kakao:
            let service = await KakaoLoginService()
            return try await service.login()
        case .apple:
            let service = await AppleLoginService()
            return try await service.login()
        }
    }
}
