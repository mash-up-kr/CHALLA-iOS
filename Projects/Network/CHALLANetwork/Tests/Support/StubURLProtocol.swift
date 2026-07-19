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

    /// 다음 요청에 돌려줄 스텁.
    nonisolated(unsafe) static var stub: Stub?
    /// 마지막으로 가로챈 요청 (헤더 검증용).
    nonisolated(unsafe) static var lastRequest: URLRequest?

    static func reset() {
        stub = nil
        lastRequest = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        StubURLProtocol.lastRequest = request

        guard let stub = StubURLProtocol.stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension URLSession {
    /// `StubURLProtocol`을 끼운 격리 세션.
    static func stubbed() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
