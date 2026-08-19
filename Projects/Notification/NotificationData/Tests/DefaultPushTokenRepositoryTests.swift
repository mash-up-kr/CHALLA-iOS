@testable import NotificationData
import CHALLANetwork
import CHALLANetworkTesting
import Foundation
import NotificationDomain
import Testing

/// 서버 계약(경로 · 메서드 · envelope 모양)과 오류 정규화를 고정한다.
@Suite("DefaultPushTokenRepository")
struct DefaultPushTokenRepositoryTests {

    private static let token = "fcm-registration-token"

    /// 등록·해제 응답에는 `data` 키가 아예 없다 (서버 `ApiResponseUnit`).
    private static let unitResponse = #"{"success":true,"message":"OK"}"#

    // MARK: - 라우팅 계약

    @Test("토큰 등록은 POST /api/v1/notifications/tokens 로 간다")
    func registerRoutesToTokens() async throws {
        let client = MockHTTPClient.returning(json: Self.unitResponse)
        let repository = DefaultPushTokenRepository(client: client)

        try await repository.register(token: Self.token)

        let request = try #require(client.requests.first)
        #expect(client.requests.count == 1)
        #expect(request.path == "/api/v1/notifications/tokens")
        #expect(request.method == .post)
        #expect(request.usesBearerToken)
    }

    @Test("토큰 해제는 DELETE 로 가고 토큰을 본문에 싣는다 — query 파라미터가 아니다")
    func unregisterSendsTokenInBody() async throws {
        let client = MockHTTPClient.returning(json: Self.unitResponse)
        let repository = DefaultPushTokenRepository(client: client)

        try await repository.unregister(token: Self.token)

        let request = try #require(client.requests.first)
        #expect(request.path == "/api/v1/notifications/tokens")
        #expect(request.method == .delete)

        let body = try #require(request.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let notification = try #require(json["notification"] as? [String: Any])
        #expect(notification["token"] as? String == Self.token)
    }

    @Test("등록 본문도 notification 키로 한 번 감싼다")
    func registerWrapsBodyInNotificationKey() async throws {
        let client = MockHTTPClient.returning(json: Self.unitResponse)
        let repository = DefaultPushTokenRepository(client: client)

        try await repository.register(token: Self.token)

        let body = try #require(client.requests.first?.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let notification = try #require(json["notification"] as? [String: Any])
        #expect(notification["token"] as? String == Self.token)
        #expect(json.keys.count == 1) // 토큰이 최상위로 새지 않는다
    }

    @Test("테스트 발송은 POST /api/v1/notifications/test 로 가고 sentCount를 돌려준다")
    func sendTestPushReturnsSentCount() async throws {
        let client = MockHTTPClient.returning(
            json: #"{"success":true,"message":"OK","data":{"notification":{"sentCount":2}}}"#
        )
        let repository = DefaultPushTokenRepository(client: client)

        let sentCount = try await repository.sendTestPush(title: "제목", body: "본문")

        let request = try #require(client.requests.first)
        #expect(request.path == "/api/v1/notifications/test")
        #expect(request.method == .post)
        #expect(sentCount == 2)
    }

    @Test("등록된 토큰이 없으면 sentCount가 0으로 온다 — 등록 성공 여부를 이걸로 판별한다")
    func sendTestPushReportsZeroWhenNoToken() async throws {
        let client = MockHTTPClient.returning(
            json: #"{"success":true,"message":"OK","data":{"notification":{"sentCount":0}}}"#
        )
        let repository = DefaultPushTokenRepository(client: client)

        #expect(try await repository.sendTestPush(title: "제목", body: "본문") == 0)
    }

    // MARK: - 오류 정규화

    @Test("전송 실패는 .network으로 정규화된다")
    func normalizesTransportFailure() async {
        let client = MockHTTPClient.failing(
            NetworkError.transport(underlying: URLError(.notConnectedToInternet))
        )
        let repository = DefaultPushTokenRepository(client: client)

        await #expect(throws: NotificationError.network) {
            try await repository.register(token: Self.token)
        }
    }

    @Test("401은 .unauthorized로 정규화된다")
    func normalizesUnauthorized() async {
        let client = MockHTTPClient.failing(
            NetworkError.unacceptableStatusCode(
                statusCode: 401,
                response: Response(statusCode: 401, data: Data())
            )
        )
        let repository = DefaultPushTokenRepository(client: client)

        await #expect(throws: NotificationError.unauthorized) {
            try await repository.unregister(token: Self.token)
        }
    }

    @Test("success=false면 서버 메시지를 담은 .server로 던진다")
    func throwsServerErrorWhenNotSuccessful() async {
        let client = MockHTTPClient.returning(
            json: #"{"success":false,"message":"토큰이 유효하지 않습니다"}"#
        )
        let repository = DefaultPushTokenRepository(client: client)

        await #expect(throws: NotificationError.server(message: "토큰이 유효하지 않습니다")) {
            try await repository.register(token: Self.token)
        }
    }

    @Test("취소는 NotificationError로 감싸지 않고 그대로 통과시킨다")
    func passesCancellationThrough() async {
        let client = MockHTTPClient.failing(CancellationError())
        let repository = DefaultPushTokenRepository(client: client)

        await #expect(throws: CancellationError.self) {
            try await repository.register(token: Self.token)
        }
    }
}
