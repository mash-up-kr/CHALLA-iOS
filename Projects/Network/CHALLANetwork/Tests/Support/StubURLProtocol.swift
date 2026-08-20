import Foundation

/// `URLSession` 전송을 가로채 미리 지정한 응답/오류를 돌려주는 스텁.
/// 실제 서버 없이 `DefaultHTTPClient`의 전체 파이프라인을 검증하는 데 쓴다.
///
/// 클래스 전역 상태를 공유하므로 이를 쓰는 테스트 스위트는 `.serialized`로 직렬 실행한다.
final class StubURLProtocol: URLProtocol {

    struct Stub {
        var statusCode: Int
        var data: Data
        var error: Error?
        var headers: [String: String]
    }

    nonisolated(unsafe) static var stub: Stub?
    /// 재시도처럼 한 테스트에서 응답이 여러 번 필요할 때 앞에서부터 꺼내 쓴다 (비면 `stub`으로 되돌아간다).
    nonisolated(unsafe) static var queuedStubs: [Stub] = []
    /// 가로챈 요청 전체 (재시도 시 헤더가 갱신됐는지 검증용).
    nonisolated(unsafe) static var requests: [URLRequest] = []

    /// 마지막으로 가로챈 요청 (헤더 검증용).
    static var lastRequest: URLRequest? {
        requests.last
    }

    static func reset() {
        stub = nil
        queuedStubs = []
        requests = []
    }

    private static func nextStub() -> Stub? {
        queuedStubs.isEmpty ? stub : queuedStubs.removeFirst()
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        StubURLProtocol.requests.append(request)

        guard let stub = StubURLProtocol.nextStub() else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        guard
            let url = request.url,
            let response = HTTPURLResponse(
                url: url,
                statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: stub.headers
            )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension URLSession {
    static func stubbed() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
