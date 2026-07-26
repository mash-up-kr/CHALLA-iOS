import Foundation
import AuthDomain
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser

/// 카카오 소셜 로그인 (KakaoSDK 순정). OIDC `idToken`을 `SocialCredential`로 반환한다.
///
/// - 카카오톡 설치 시 앱 전환 로그인, 미설치/시뮬레이터는 계정(웹) 로그인으로 자동 폴백.
/// - SDK UI가 메인 스레드를 요구하므로 `@MainActor` 격리.
@MainActor
struct KakaoLoginService {

    // MARK: - Public Methods

    /// 실패는 전부 `AuthError`로 정규화한다 (사용자 취소 → `.cancelled`).
    func login() async throws -> SocialCredential {
        try await withCheckedThrowingContinuation { continuation in
            let handler: @Sendable (OAuthToken?, (any Error)?) -> Void = { token, error in
                if let error {
                    continuation.resume(throwing: Self.mapError(error))
                    return
                }
                guard let idToken = token?.idToken else {   // OIDC 미설정 시 nil
                    // TODO: 임의 작성 문구 — 추후 기획 정책 확정 시 교체할 것.
                    continuation.resume(throwing: AuthError.social(reason: "Kakao idToken을 받지 못했어요."))
                    return
                }
                continuation.resume(returning: SocialCredential(
                    provider: .kakao,
                    idToken: idToken,
                    authorizationCode: nil
                ))
            }

            if UserApi.isKakaoTalkLoginAvailable() {
                UserApi.shared.loginWithKakaoTalk(completion: handler)
            } else {
                UserApi.shared.loginWithKakaoAccount(completion: handler)
            }
        }
    }

    // MARK: - Private Methods

    /// KakaoSDK 오류 → `AuthError` 정규화.
    ///
    /// SDK 소스(2.28.0)에서 확인한 취소 경로 두 가지를 `.cancelled`로 매핑한다:
    /// - `.ClientFailed(reason: .Cancelled, _)` — 카카오톡 앱 전환/웹 인증 세션을 사용자가 닫음
    ///   (`AuthController`가 `ASWebAuthenticationSessionError.canceledLogin`도 이 케이스로 변환한다)
    /// - `.AuthFailed(reason: .AccessDenied, _)` — 동의 화면에서 사용자가 로그인을 취소함
    private nonisolated static func mapError(_ error: any Error) -> AuthError {
        guard let sdkError = error as? SdkError else {
            return .social(reason: error.localizedDescription)
        }
        switch sdkError {
        case .ClientFailed(reason: .Cancelled, errorMessage: _):
            return .cancelled
        case .AuthFailed(reason: .AccessDenied, errorInfo: _):
            return .cancelled
        default:
            return .social(reason: error.localizedDescription)
        }
    }
}
