import AuthDomain
import CHALLANetwork
import Foundation

/// `AuthRepository` 구현 — 인증 서버 호출 + DTO 언랩 + 오류 정규화.
///
/// 밖으로 던지는 오류는 전부 `AuthError`다 (Domain 규약):
/// `unwrap()`이 던진 도메인 오류는 그대로, `NetworkError`는 매핑 규칙으로, 그 외는 `.unknown`.
public struct DefaultAuthRepository: AuthRepository {

    // MARK: - Properties

    /// 라이브는 `DefaultHTTPClient`, 테스트는 Mock을 주입한다.
    let client: any HTTPClient

    // MARK: - Init

    public init(client: any HTTPClient) {
        self.client = client
    }

    // MARK: - Public Methods

    public func login(_ credential: SocialCredential) async throws -> AuthSession {
        do {
            let requestDTO = LoginRequestDTO(from: credential)
            let envelope = try await client.request(
                AuthEndpoint.login(requestDTO),
                as: BaseResponseDTO<LoginResponseDTO>.self
            )
            let payload = try envelope.unwrap()
            return AuthSession(
                token: AuthToken(accessToken: payload.accessToken, refreshToken: payload.refreshToken),
                isNewUser: payload.isNewUser
            )
        } catch {
            throw Self.normalize(error)
        }
    }

    public func refresh(refreshToken: String) async throws -> AuthToken {
        do {
            let requestDTO = RefreshRequestDTO(refreshToken: refreshToken)
            let envelope = try await client.request(
                AuthEndpoint.refresh(requestDTO),
                as: BaseResponseDTO<TokenPairResponseDTO>.self
            )
            let payload = try envelope.unwrap()
            return AuthToken(
                accessToken: payload.accessToken,
                refreshToken: payload.refreshToken
            )
        } catch {
            throw Self.normalize(error)
        }
    }

    public func logout(refreshToken: String) async throws {
        do {
            let requestDTO = LogoutRequestDTO(refreshToken: refreshToken)
            let envelope = try await client.request(
                AuthEndpoint.logout(requestDTO),
                as: BaseResponseDTO<EmptyResponseDTO>.self
            )
            try envelope.ensureSuccess() // 페이로드는 무시, 실패만 매핑
        } catch {
            throw Self.normalize(error)
        }
    }

    // MARK: - Private Methods

    /// 어떤 오류가 새어 나와도 `AuthError`로 정규화한다.
    private static func normalize(_ error: any Error) -> AuthError {
        switch error {
        case let authError as AuthError:
            return authError // unwrap이 던진 도메인 오류 그대로
        case let networkError as NetworkError:
            return AuthError(networkError: networkError)
        default:
            return .unknown
        }
    }
}
