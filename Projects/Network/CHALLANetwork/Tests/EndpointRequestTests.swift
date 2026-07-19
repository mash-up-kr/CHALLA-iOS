import Testing
import Foundation
@testable import CHALLANetwork

@Suite("Endpoint → URLRequest 변환")
struct EndpointRequestTests {

    @Test("baseURL·path·method·headers를 반영한다")
    func basicConversion() throws {
        var endpoint = TestEndpoint()
        endpoint.path = "/v1/rooms"
        endpoint.method = .get
        endpoint.headers = ["X-Trace": "abc"]

        let request = try endpoint.asURLRequest()

        #expect(request.url?.absoluteString == "https://api.example.com/v1/rooms")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "X-Trace") == "abc")
    }

    @Test("requestPlain은 본문이 없다")
    func requestPlain() throws {
        let request = try TestEndpoint().asURLRequest()
        #expect(request.httpBody == nil)
    }

    @Test("requestData는 본문을 그대로 싣는다")
    func requestData() throws {
        var endpoint = TestEndpoint()
        endpoint.method = .post
        endpoint.task = .requestData(Data("raw".utf8))

        let request = try endpoint.asURLRequest()

        #expect(request.httpBody == Data("raw".utf8))
    }

    @Test("requestJSONEncodable은 JSON 본문과 Content-Type을 만든다")
    func jsonEncodable() throws {
        struct Body: Codable, Equatable { let name: String; let count: Int }
        var endpoint = TestEndpoint()
        endpoint.method = .post
        endpoint.task = .requestJSONEncodable(Body(name: "challa", count: 3))

        let request = try endpoint.asURLRequest()

        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try JSONDecoder().decode(Body.self, from: #require(request.httpBody))
        #expect(body == Body(name: "challa", count: 3))
    }

    @Test("requestParameters(GET)는 쿼리스트링을 붙인다")
    func requestParametersQuery() throws {
        var endpoint = TestEndpoint()
        endpoint.path = "/search"
        endpoint.task = .requestParameters(parameters: ["q": "film"], encoding: URLEncoding.default)

        let request = try endpoint.asURLRequest()

        #expect(request.url?.absoluteString == "https://api.example.com/search?q=film")
    }

    @Test("uploadMultipart는 multipart Content-Type과 파트 데이터를 담는다")
    func multipart() throws {
        var endpoint = TestEndpoint()
        endpoint.method = .post
        let part = MultipartFormData(
            data: Data("imgbytes".utf8),
            name: "photo",
            fileName: "p.jpg",
            mimeType: "image/jpeg"
        )
        endpoint.task = .uploadMultipart([part])

        let request = try endpoint.asURLRequest()

        let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
        #expect(contentType.hasPrefix("multipart/form-data; boundary="))
        let httpBody = try #require(request.httpBody)
        let bodyString = try #require(String(data: httpBody, encoding: .utf8))
        #expect(bodyString.contains(#"Content-Disposition: form-data; name="photo"; filename="p.jpg""#))
        #expect(bodyString.contains("Content-Type: image/jpeg"))
        #expect(bodyString.contains("imgbytes"))
    }
}
