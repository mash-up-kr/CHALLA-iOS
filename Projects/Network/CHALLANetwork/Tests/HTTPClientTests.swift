@testable import CHALLANetwork
import Foundation
import os
import Testing

/// 전역 스텁 상태를 공유하므로 직렬 실행한다.
@Suite("DefaultHTTPClient", .serialized)
struct HTTPClientTests {

    /// Swift Testing은 테스트마다 스위트 인스턴스를 새로 만든다 — 전역 스텁을 여기서 초기화한다.
    init() {
        StubURLProtocol.reset()
    }

    @Test("성공 응답을 Response로 돌려준다")
    func success() async throws {
        StubURLProtocol.stub = .init(
            statusCode: 200,
            data: Data(#"{"ok":true}"#.utf8),
            error: nil,
            headers: ["Content-Type": "application/json"]
        )
        let client = DefaultHTTPClient(session: .stubbed())

        let response = try await client.request(TestEndpoint())

        #expect(response.statusCode == 200)
        #expect(response.data == Data(#"{"ok":true}"#.utf8))
    }

    @Test("응답 헤더를 [String: String]로 노출한다")
    func responseHeaders() async throws {
        StubURLProtocol.stub = .init(
            statusCode: 200,
            data: Data(),
            error: nil,
            headers: ["Content-Type": "application/json", "X-Trace": "42"]
        )
        let client = DefaultHTTPClient(session: .stubbed())

        let response = try await client.request(TestEndpoint())

        #expect(response.headers["X-Trace"] == "42")
        #expect(response.headers["Content-Type"] == "application/json")
    }

    @Test("편의 request(as:)는 2xx 필터 후 디코딩한다")
    func decodeConvenience() async throws {
        struct Model: Decodable, Equatable { let ok: Bool }
        StubURLProtocol.stub = .init(statusCode: 200, data: Data(#"{"ok":true}"#.utf8), error: nil, headers: [:])
        let client = DefaultHTTPClient(session: .stubbed())

        let model = try await client.request(TestEndpoint(), as: Model.self)

        #expect(model == Model(ok: true))
    }

    @Test("404는 raw Response로 오지만 편의 메서드는 상태 코드 오류를 던진다")
    func notFound() async throws {
        StubURLProtocol.stub = .init(statusCode: 404, data: Data(), error: nil, headers: [:])
        let client = DefaultHTTPClient(session: .stubbed())

        let raw = try await client.request(TestEndpoint())
        #expect(raw.statusCode == 404)

        let error = try await #require(throws: NetworkError.self) {
            _ = try await client.request(TestEndpoint(), as: EmptyModel.self)
        }
        #expect(error.unacceptableStatusCode == 404)
    }

    @Test("전송 실패는 원본 URLError를 실은 transport 오류로 감싼다")
    func transportError() async throws {
        StubURLProtocol.stub = .init(
            statusCode: 0,
            data: Data(),
            error: URLError(.notConnectedToInternet),
            headers: [:]
        )
        let client = DefaultHTTPClient(session: .stubbed())

        let error = try await #require(throws: NetworkError.self) {
            _ = try await client.request(TestEndpoint())
        }

        #expect((error.transportUnderlying as? URLError)?.code == .notConnectedToInternet)
    }

    @Test("취소는 NetworkError로 감싸지 않고 CancellationError로 던진다")
    func cancellationIsNotWrapped() async throws {
        StubURLProtocol.stub = .init(statusCode: 0, data: Data(), error: URLError(.cancelled), headers: [:])
        let client = DefaultHTTPClient(session: .stubbed())

        await #expect(throws: CancellationError.self) {
            _ = try await client.request(TestEndpoint())
        }
    }

    @Test("취소는 인터셉터에 실패로 통보하지 않는다 (일반 전송 실패는 통보한다)")
    func cancellationIsNotReportedToInterceptors() async {
        let recorder = FailureRecordingInterceptor()
        let client = DefaultHTTPClient(session: .stubbed(), interceptors: [recorder])

        StubURLProtocol.stub = .init(statusCode: 0, data: Data(), error: URLError(.cancelled), headers: [:])
        _ = try? await client.request(TestEndpoint())
        #expect(recorder.failureCount == 0)

        StubURLProtocol.stub = .init(statusCode: 0, data: Data(), error: URLError(.timedOut), headers: [:])
        _ = try? await client.request(TestEndpoint())
        #expect(recorder.failureCount == 1)
    }

    @Test("인터셉터 adapt 결과가 실제 요청 헤더에 반영된다")
    func interceptorAdaptApplied() async throws {
        StubURLProtocol.stub = .init(statusCode: 200, data: Data(), error: nil, headers: [:])
        let client = DefaultHTTPClient(
            session: .stubbed(),
            interceptors: [AuthInterceptor(tokenProvider: FakeTokenProvider(token: "xyz"))]
        )

        _ = try await client.request(TestEndpoint())

        #expect(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer xyz")
    }

    @Test("인터셉터는 등록 순서대로 adapt가 연쇄 적용된다")
    func interceptorsChainInOrder() async throws {
        StubURLProtocol.stub = .init(statusCode: 200, data: Data(), error: nil, headers: [:])
        let client = DefaultHTTPClient(
            session: .stubbed(),
            interceptors: [
                HeaderStampInterceptor(value: "first"),
                HeaderStampInterceptor(value: "second")
            ]
        )

        _ = try await client.request(TestEndpoint())

        // 뒤에 등록된 인터셉터가 앞의 결과 위에 덮어쓴다.
        #expect(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "X-Stamp") == "second")
    }

    @Test("401을 받으면 토큰을 갱신하고 갱신된 토큰으로 한 번 재시도한다")
    func retriesUnauthorizedWithRefreshedToken() async throws {
        StubURLProtocol.queuedStubs = [
            .init(statusCode: 401, data: Data(), error: nil, headers: [:]),
            .init(statusCode: 200, data: Data(#"{"ok":true}"#.utf8), error: nil, headers: [:])
        ]
        let provider = MutableTokenProvider(token: "old")
        let client = DefaultHTTPClient(
            session: .stubbed(),
            interceptors: [AuthInterceptor(tokenProvider: provider)],
            retrier: TokenRefreshRetrier(refresher: RotatingTokenRefresher(provider: provider))
        )

        let response = try await client.request(TestEndpoint())

        #expect(response.statusCode == 200)
        #expect(StubURLProtocol.requests.count == 2)
        #expect(StubURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer old")
        // 재시도는 파이프라인 처음으로 돌아가므로 adapt가 다시 돌아 새 토큰이 실린다.
        #expect(StubURLProtocol.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer new")
    }

    @Test("갱신이 실패하면 재시도하지 않고 401을 그대로 돌려준다")
    func doesNotRetryWhenRefreshFails() async throws {
        StubURLProtocol.stub = .init(statusCode: 401, data: Data(), error: nil, headers: [:])
        let client = DefaultHTTPClient(
            session: .stubbed(),
            retrier: TokenRefreshRetrier(refresher: FakeTokenRefresher(result: false))
        )

        let response = try await client.request(TestEndpoint())

        #expect(response.statusCode == 401)
        #expect(StubURLProtocol.requests.count == 1)
    }

    @Test("재시도한 응답이 또 401이면 더는 시도하지 않는다 (무한 갱신 방지)")
    func stopsAfterSingleRetry() async throws {
        StubURLProtocol.stub = .init(statusCode: 401, data: Data(), error: nil, headers: [:])
        let refresher = FakeTokenRefresher(result: true)
        let client = DefaultHTTPClient(
            session: .stubbed(),
            retrier: TokenRefreshRetrier(refresher: refresher)
        )

        let response = try await client.request(TestEndpoint())

        #expect(response.statusCode == 401)
        #expect(StubURLProtocol.requests.count == 2)
        #expect(refresher.callCount == 1)
    }

    @Test("retrier가 없으면 401도 그대로 돌려준다 (기존 동작 유지)")
    func withoutRetrierKeepsUnauthorized() async throws {
        StubURLProtocol.stub = .init(statusCode: 401, data: Data(), error: nil, headers: [:])
        let client = DefaultHTTPClient(session: .stubbed())

        let response = try await client.request(TestEndpoint())

        #expect(response.statusCode == 401)
        #expect(StubURLProtocol.requests.count == 1)
    }
}

private struct EmptyModel: Decodable {}

/// 갱신 전후로 토큰이 바뀌는 상황을 재현한다.
private final class MutableTokenProvider: TokenProvider {
    private let current: OSAllocatedUnfairLock<String>

    init(token: String) {
        current = OSAllocatedUnfairLock(initialState: token)
    }

    func set(_ token: String) {
        current.withLock { $0 = token }
    }

    func accessToken() async -> String? {
        current.withLock { $0 }
    }
}

private struct RotatingTokenRefresher: TokenRefreshing {
    let provider: MutableTokenProvider

    func refreshToken(replacing _: String?) async -> Bool {
        provider.set("new")
        return true
    }
}

/// 연쇄 순서 확인용 — 고정 헤더 하나만 덮어쓴다.
/// `didReceive`로 통보된 실패 횟수만 세는 인터셉터.
/// 호출을 누적하려면 참조 시맨틱이 필요해 final class + 락으로 구성한다.
private final class FailureRecordingInterceptor: Interceptor {
    private let failures = OSAllocatedUnfairLock<Int>(initialState: 0)

    var failureCount: Int {
        failures.withLock { $0 }
    }

    func didReceive(_ result: Result<Response, NetworkError>, endpoint _: any Endpoint) {
        guard case .failure = result else { return }
        failures.withLock { $0 += 1 }
    }
}

private struct HeaderStampInterceptor: Interceptor {
    let value: String

    func adapt(_ request: URLRequest, for _: any Endpoint) async throws -> URLRequest {
        var request = request
        request.setValue(value, forHTTPHeaderField: "X-Stamp")
        return request
    }
}
