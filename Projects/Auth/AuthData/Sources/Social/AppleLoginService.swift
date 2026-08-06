import AuthDomain
import AuthenticationServices
import UIKit

/// Apple 소셜 로그인 (AuthenticationServices). `identityToken`을 `SocialCredential`로 반환한다.
///
/// - 성공/실패 모두 `finish(with:)` 한 곳으로 모아 resume 직후 `nil` 처리한다.
@MainActor
final class AppleLoginService: NSObject {

    // MARK: - Properties

    private var continuation: CheckedContinuation<SocialCredential, any Error>?
    private var controller: ASAuthorizationController?

    // MARK: - Initialization

    /// 격리 추론 모호성을 없애기 위한 명시 선언 — 이 클래스는 항상 메인 액터에서 생성된다.
    override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// 실패는 전부 `AuthError`로 정규화한다 (사용자 취소 → `.cancelled`).
    func login() async throws -> SocialCredential {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard self.continuation == nil else {
                    // TODO: 임의 작성 문구 — 추후 기획 정책 확정 시 교체할 것.
                    continuation.resume(throwing: AuthError.social(reason: "이미 Apple 로그인이 진행 중이에요."))
                    return
                }
                self.continuation = continuation

                guard !Task.isCancelled else {
                    finish(with: .failure(.cancelled))
                    return
                }

                let request = ASAuthorizationAppleIDProvider().createRequest()
                request.requestedScopes = [.fullName, .email] // 서버 요구에 맞춰 조정

                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                self.controller = controller
                controller.performRequests()
            }
        } onCancel: {
            Task { @MainActor in
                controller?.cancel()
                finish(with: .failure(.cancelled))
            }
        }
    }

    // MARK: - Private Methods

    /// continuation을 정확히 1회 resume하고 상태를 비운다. 모든 종료 경로가 여기를 지난다.
    private func finish(with result: Result<SocialCredential, AuthError>) {
        switch result {
        case let .success(credential):
            continuation?.resume(returning: credential)
        case let .failure(error):
            continuation?.resume(throwing: error)
        }
        continuation = nil
        controller = nil
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleLoginService: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let idTokenData = credential.identityToken,
              let idToken = String(data: idTokenData, encoding: .utf8) else {
            // TODO: 임의 작성 문구 — 추후 기획 정책 확정 시 교체할 것.
            finish(with: .failure(.social(reason: "Apple 토큰을 받지 못했어요.")))
            return
        }
        let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        finish(with: .success(SocialCredential(
            provider: .apple,
            idToken: idToken,
            authorizationCode: code
        )))
    }

    func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        let mapped: AuthError = (error as? ASAuthorizationError)?.code == .canceled
            ? .cancelled
            : .social(reason: error.localizedDescription)
        finish(with: .failure(mapped))
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleLoginService: ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        // 활성 씬의 keyWindow를 우선으로, 없으면 단계적으로 폴백해 프레젠테이션 실패를 피한다.
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let activeScene = windowScenes.first { $0.activationState == .foregroundActive }
            ?? windowScenes.first

        return activeScene?.keyWindow
            ?? activeScene?.windows.first
            ?? ASPresentationAnchor()
    }
}
