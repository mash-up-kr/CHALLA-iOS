import Foundation
import AuthDomain

/// `SocialLoginService` 구현 — provider별 서비스로 라우팅한다.
///
/// 각 서비스는 `@MainActor`라 `await`로 자동 hop하고,
/// 경계를 넘어오는 값은 `Sendable`인 `SocialCredential`뿐이다.
public struct DefaultSocialLoginService: SocialLoginService {

    public init() {}

    public func authenticate(_ provider: AuthProvider) async throws -> SocialCredential {
        switch provider {
        case .kakao:
            return try await KakaoLoginService().login()
        case .apple:
            // 델리게이트 콜백까지 인스턴스가 살아 있어야 하므로
            // await 동안 로컬 상수로 강참조를 유지한다.
            let service = await AppleLoginService()
            return try await service.login()
        }
    }
}
