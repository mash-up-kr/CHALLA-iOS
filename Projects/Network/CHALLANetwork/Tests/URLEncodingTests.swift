import Testing
import Foundation
@testable import CHALLANetwork

@Suite("URLEncoding")
struct URLEncodingTests {

    private let base = URLRequest(url: URL(string: "https://a.com/x")!)

    /// 퍼센트 인코딩된 쿼리 문자열만 뽑는다 (percentEncodedQuery는 URLComponents의 프로퍼티).
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
}
