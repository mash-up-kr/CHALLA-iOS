import Testing
import Foundation
@testable import CHALLANetwork

@Suite("URLEncoding")
struct URLEncodingTests {

    private let base = URLRequest(url: URL(string: "https://a.com/x")!)

    /// 이스케이프 결과를 그대로 보려면 정규화되지 않은 원본 쿼리가 필요하다 (`url.query`는 디코딩됨).
    private func percentEncodedQuery(_ request: URLRequest) throws -> String? {
        try URLComponents(url: #require(request.url), resolvingAgainstBaseURL: false)?.percentEncodedQuery
    }

    @Test("파라미터를 키 정렬해 쿼리스트링으로 인코딩한다")
    func scalarQuery() throws {
        let encoded = try URLEncoding.default.encode(base, with: ["b": "2", "a": "1"])
        #expect(encoded.url?.query == "a=1&b=2")
    }

    @Test("공백·예약문자를 퍼센트 인코딩한다")
    func escaping() throws {
        let encoded = try URLEncoding.default.encode(base, with: ["q": "hello world&x"])
        #expect(try percentEncodedQuery(encoded) == "q=hello%20world%26x")
    }

    @Test("빈 파라미터는 요청을 바꾸지 않는다")
    func emptyParameters() throws {
        let encoded = try URLEncoding.default.encode(base, with: [:])
        #expect(encoded.url == base.url)
    }

    @Test("이미 쿼리가 있는 URL에는 &로 이어붙인다")
    func mergesWithExistingQuery() throws {
        let request = URLRequest(url: URL(string: "https://a.com/x?page=1")!)
        let encoded = try URLEncoding.default.encode(request, with: ["q": "film"])
        #expect(encoded.url?.query == "page=1&q=film")
    }
}
