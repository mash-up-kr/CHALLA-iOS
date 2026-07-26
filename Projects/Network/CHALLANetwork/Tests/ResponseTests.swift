import Testing
import Foundation
@testable import CHALLANetwork

@Suite("Response")
struct ResponseTests {

    private func makeResponse(status: Int, data: Data = Data()) -> Response {
        Response(statusCode: status, data: data)
    }

    @Test("2xx는 filterSuccessfulStatusCodes를 통과한다")
    func filterSuccess() throws {
        let response = makeResponse(status: 201)
        #expect(try response.filterSuccessfulStatusCodes().statusCode == 201)
    }

    @Test("비2xx는 상태 코드를 담은 unacceptableStatusCode를 던진다")
    func filterFailure() throws {
        let response = makeResponse(status: 404)

        let error = try #require(throws: NetworkError.self) {
            try response.filterSuccessfulStatusCodes()
        }

        #expect(error.unacceptableStatusCode == 404)
    }

    @Test("filter(statusCodes:)는 지정 범위로 판정한다")
    func customRange() throws {
        let response = makeResponse(status: 302)

        let error = try #require(throws: NetworkError.self) {
            try response.filter(statusCodes: 200..<300)
        }

        #expect(error.unacceptableStatusCode == 302)
        #expect(try response.filter(statusCodes: 300..<400).statusCode == 302)
    }

    @Test("map은 JSON 본문을 모델로 디코딩한다")
    func mapDecodes() throws {
        struct Model: Decodable, Equatable { let id: Int }
        let response = makeResponse(status: 200, data: Data(#"{"id": 7}"#.utf8))
        #expect(try response.map(Model.self) == Model(id: 7))
    }

    @Test("map 실패는 원본 응답을 실은 decoding 오류로 감싼다")
    func mapFailure() throws {
        struct Model: Decodable { let id: Int }
        let response = makeResponse(status: 200, data: Data("not json".utf8))

        let error = try #require(throws: NetworkError.self) {
            try response.map(Model.self)
        }

        // 디버깅에 쓰이도록 원문이 오류에 함께 실려야 한다.
        #expect(error.decodingResponse?.data == Data("not json".utf8))
    }
}
