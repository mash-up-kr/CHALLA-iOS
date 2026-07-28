@testable import CHALLANetwork
import Foundation
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
}

private struct EmptyModel: Decodable {}

/// 연쇄 순서 확인용 — 고정 헤더 하나만 덮어쓴다.
private struct HeaderStampInterceptor: Interceptor {
    let value: String

    func adapt(_ request: URLRequest, for _: any Endpoint) async throws -> URLRequest {
        var request = request
        request.setValue(value, forHTTPHeaderField: "X-Stamp")
        return request
    }
}
