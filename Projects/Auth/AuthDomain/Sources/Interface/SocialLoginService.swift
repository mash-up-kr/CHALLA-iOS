import Foundation

/// 소셜(카카오/애플) 네이티브 인증 추상. 구현은 `AuthData`가 맡는다.
public protocol SocialLoginService: Sendable {

    /// 지정 provider의 네이티브 소셜 로그인 UI를 띄우고 자격증명을 반환한다.
    func authenticate(_ provider: AuthProvider) async throws -> SocialCredential
}
