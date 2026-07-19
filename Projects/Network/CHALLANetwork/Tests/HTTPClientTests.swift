import Testing
import Foundation
@testable import CHALLANetwork

// 전역 스텁 상태를 공유하므로 직렬 실행한다.
@Suite("DefaultHTTPClient", .serialized)
struct HTTPClientTests {

    @Test("성공 응답을 Response로 돌려준다")
    func success() async throws {
        StubURLProtocol.reset()
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
        StubURLProtocol.reset()
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
        StubURLProtocol.reset()
        StubURLProtocol.stub = .init(statusCode: 200, data: Data(#"{"ok":true}"#.utf8), error: nil, headers: [:])
        let client = DefaultHTTPClient(session: .stubbed())

        let model = try await client.request(TestEndpoint(), as: Model.self)

        #expect(model == Model(ok: true))
    }

    @Test("404는 raw Response로 오지만 편의 메서드는 오류를 던진다")
    func notFound() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.stub = .init(statusCode: 404, data: Data(), error: nil, headers: [:])
        let client = DefaultHTTPClient(session: .stubbed())

        let raw = try await client.request(TestEndpoint())
        #expect(raw.statusCode == 404)

        await #expect(throws: NetworkError.self) {
            _ = try await client.request(TestEndpoint(), as: EmptyModel.self)
        }
    }

    @Test("전송 실패는 transport 오류로 감싼다")
    func transportError() async {
        StubURLProtocol.reset()
        StubURLProtocol.stub = .init(
            statusCode: 0,
            data: Data(),
            error: URLError(.notConnectedToInternet),
            headers: [:]
        )
        let client = DefaultHTTPClient(session: .stubbed())

        await #expect(throws: NetworkError.self) {
            _ = try await client.request(TestEndpoint())
        }
    }

    @Test("인터셉터 adapt 결과가 실제 요청 헤더에 반영된다")
    func interceptorAdaptApplied() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.stub = .init(statusCode: 200, data: Data(), error: nil, headers: [:])
        let client = DefaultHTTPClient(
            session: .stubbed(),
            interceptors: [AuthInterceptor(tokenProvider: FakeTokenProvider(token: "xyz"))]
        )

        _ = try await client.request(TestEndpoint())

        #expect(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer xyz")
    }
}

private struct EmptyModel: Decodable {}
