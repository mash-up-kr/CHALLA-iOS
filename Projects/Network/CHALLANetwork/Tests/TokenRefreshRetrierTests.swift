@testable import CHALLANetwork
import Foundation
import Testing

@Suite("TokenRefreshRetrier")
struct TokenRefreshRetrierTests {

    private func response(
        statusCode: Int,
        authorization: String? = nil
    ) -> Result<Response, NetworkError> {
        var request = URLRequest(url: URL(string: "https://api.example.com/secure")!)
        if let authorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        return .success(Response(statusCode: statusCode, data: Data(), request: request))
    }

    @Test("401이면 갱신을 시도하고, 갱신 성공 시 재시도한다")
    func retriesAfterSuccessfulRefresh() async {
        let refresher = FakeTokenRefresher(result: true)
        let retrier = TokenRefreshRetrier(refresher: refresher)

        let shouldRetry = await retrier.shouldRetry(
            response(statusCode: 401),
            endpoint: TestEndpoint(),
            attempt: 0
        )

        #expect(shouldRetry)
        #expect(refresher.callCount == 1)
    }

    @Test("갱신이 실패하면 재시도하지 않는다 — 401이 그대로 올라가 재로그인으로 이어진다")
    func doesNotRetryWhenRefreshFails() async {
        let refresher = FakeTokenRefresher(result: false)
        let retrier = TokenRefreshRetrier(refresher: refresher)

        let shouldRetry = await retrier.shouldRetry(
            response(statusCode: 401),
            endpoint: TestEndpoint(),
            attempt: 0
        )

        #expect(!shouldRetry)
    }

    @Test("401이 아닌 응답은 갱신을 부르지 않는다", arguments: [200, 400, 403, 500])
    func ignoresOtherStatusCodes(statusCode: Int) async {
        let refresher = FakeTokenRefresher(result: true)
        let retrier = TokenRefreshRetrier(refresher: refresher)

        let shouldRetry = await retrier.shouldRetry(
            response(statusCode: statusCode),
            endpoint: TestEndpoint(),
            attempt: 0
        )

        #expect(!shouldRetry)
        #expect(refresher.callCount == 0)
    }

    @Test("전송 실패(응답 없음)는 갱신 대상이 아니다")
    func ignoresTransportFailure() async {
        let refresher = FakeTokenRefresher(result: true)
        let retrier = TokenRefreshRetrier(refresher: refresher)

        let shouldRetry = await retrier.shouldRetry(
            .failure(.transport(underlying: URLError(.notConnectedToInternet))),
            endpoint: TestEndpoint(),
            attempt: 0
        )

        #expect(!shouldRetry)
        #expect(refresher.callCount == 0)
    }

    @Test("토큰을 싣지 않는 엔드포인트(.none)의 401은 갱신해도 달라지지 않으므로 건너뛴다")
    func ignoresUnauthorizedEndpoints() async {
        let refresher = FakeTokenRefresher(result: true)
        let retrier = TokenRefreshRetrier(refresher: refresher)

        let shouldRetry = await retrier.shouldRetry(
            response(statusCode: 401),
            endpoint: AuthTestEndpoint(authorizationType: .none),
            attempt: 0
        )

        #expect(!shouldRetry)
        #expect(refresher.callCount == 0)
    }

    @Test("재시도는 기본 1회까지만 — 두 번째 401에는 갱신조차 부르지 않는다")
    func stopsAfterMaxRetryCount() async {
        let refresher = FakeTokenRefresher(result: true)
        let retrier = TokenRefreshRetrier(refresher: refresher)

        let shouldRetry = await retrier.shouldRetry(
            response(statusCode: 401),
            endpoint: TestEndpoint(),
            attempt: 1
        )

        #expect(!shouldRetry)
        #expect(refresher.callCount == 0)
    }

    @Test("401을 받은 요청이 실어 보낸 액세스 토큰을 Bearer 접두사를 떼고 넘긴다")
    func passesStaleAccessToken() async {
        let refresher = FakeTokenRefresher(result: true)
        let retrier = TokenRefreshRetrier(refresher: refresher)

        _ = await retrier.shouldRetry(
            response(statusCode: 401, authorization: "Bearer stale-access"),
            endpoint: TestEndpoint(),
            attempt: 0
        )

        #expect(refresher.receivedStaleTokens == ["stale-access"])
    }

    @Test("인증 헤더가 없던 요청이면 만료 토큰을 nil로 넘긴다")
    func passesNilWhenRequestHadNoToken() async {
        let refresher = FakeTokenRefresher(result: true)
        let retrier = TokenRefreshRetrier(refresher: refresher)

        _ = await retrier.shouldRetry(
            response(statusCode: 401),
            endpoint: TestEndpoint(),
            attempt: 0
        )

        #expect(refresher.receivedStaleTokens == [nil])
    }
}
