import Testing
import Foundation
import AuthDomain
import CHALLANetwork
@testable import AuthData

@Suite("DefaultAuthRepository")
struct DefaultAuthRepositoryTests {

    private static let credential = SocialCredential(
        provider: .kakao,
        idToken: "id-token",
        authorizationCode: nil
    )

    // MARK: - login

    @Test("로그인 성공: BaseResponseDTO를 벗겨 AuthSession으로 변환한다")
    func loginSuccess() async throws {
        let json = """
        {"success": true, "message": "ok", "data": {"accessToken": "access", "refreshToken": "refresh", "isNewUser": true}}
        """
        let client = MockHTTPClient.returning(json: json)
        let repository = DefaultAuthRepository(client: client)

        let session = try await repository.login(Self.credential)

        #expect(session == AuthSession(
            token: AuthToken(accessToken: "access", refreshToken: "refresh"),
            isNewUser: true
        ))
        // 라우팅 계약: login은 POST /api/v1/auth/login으로 나가야 한다.
        #expect(client.requests == [.init(path: "/api/v1/auth/login", method: .post)])
    }

    @Test("success=false면 서버 메시지를 담은 .server를 던진다")
    func loginServerFailure() async {
        let json = """
        {"success": false, "message": "지원하지 않는 provider예요.", "data": null}
        """
        let repository = DefaultAuthRepository(client: MockHTTPClient.returning(json: json))

        await #expect(throws: AuthError.server(message: "지원하지 않는 provider예요.")) {
            _ = try await repository.login(Self.credential)
        }
    }

    @Test("401이면 .unauthorized를 던진다")
    func loginUnauthorized() async {
        let repository = DefaultAuthRepository(
            client: MockHTTPClient.returning(statusCode: 401, json: "{}")
        )

        await #expect(throws: AuthError.unauthorized) {
            _ = try await repository.login(Self.credential)
        }
    }

    @Test("전송 실패면 .network를 던진다")
    func loginTransportFailure() async {
        let repository = DefaultAuthRepository(
            client: MockHTTPClient.failing(
                NetworkError.transport(underlying: URLError(.notConnectedToInternet))
            )
        )

        await #expect(throws: AuthError.network) {
            _ = try await repository.login(Self.credential)
        }
    }

    // MARK: - refresh

    @Test("리프레시 성공: 토큰 쌍을 AuthToken으로 변환한다")
    func refreshSuccess() async throws {
        let json = """
        {"success": true, "message": "ok", "data": {"accessToken": "new-access", "refreshToken": "new-refresh"}}
        """
        let client = MockHTTPClient.returning(json: json)
        let repository = DefaultAuthRepository(client: client)

        let token = try await repository.refresh(refreshToken: "old-refresh")

        #expect(token == AuthToken(accessToken: "new-access", refreshToken: "new-refresh"))
        #expect(client.requests == [.init(path: "/api/v1/auth/refresh", method: .post)])
    }

    @Test("리프레시 401(만료)이면 .unauthorized를 던진다")
    func refreshUnauthorized() async {
        let repository = DefaultAuthRepository(
            client: MockHTTPClient.returning(statusCode: 401, json: "{}")
        )

        await #expect(throws: AuthError.unauthorized) {
            _ = try await repository.refresh(refreshToken: "expired")
        }
    }

    // MARK: - logout

    @Test("로그아웃 성공: data가 null이어도 통과한다 (페이로드 무시)")
    func logoutSuccess() async throws {
        let json = """
        {"success": true, "message": "ok", "data": null}
        """
        let client = MockHTTPClient.returning(json: json)
        let repository = DefaultAuthRepository(client: client)

        try await repository.logout(refreshToken: "refresh")   // throw되면 테스트 실패

        #expect(client.requests == [.init(path: "/api/v1/auth/logout", method: .post)])
    }

    @Test("로그아웃 success=false면 .server를 던진다")
    func logoutServerFailure() async {
        let json = """
        {"success": false, "message": "유효하지 않은 토큰이에요.", "data": null}
        """
        let repository = DefaultAuthRepository(client: MockHTTPClient.returning(json: json))

        await #expect(throws: AuthError.server(message: "유효하지 않은 토큰이에요.")) {
            try await repository.logout(refreshToken: "refresh")
        }
    }
}
