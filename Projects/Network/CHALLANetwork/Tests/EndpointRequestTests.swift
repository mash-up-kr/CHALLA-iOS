@testable import CHALLANetwork
import Foundation
import Testing

@Suite("Endpoint → URLRequest 변환")
struct EndpointRequestTests {

    private let encoder = JSONEncoder()

    @Test("baseURL·path·method·headers를 반영한다")
    func basicConversion() throws {
        var endpoint = TestEndpoint()
        endpoint.path = "/v1/rooms"
        endpoint.method = .get
        endpoint.headers = ["X-Trace": "abc"]

        let request = try endpoint.asURLRequest(encoder: encoder)

        #expect(request.url?.absoluteString == "https://api.example.com/v1/rooms")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "X-Trace") == "abc")
    }

    @Test("requestPlain은 본문이 없다")
    func requestPlain() throws {
        let request = try TestEndpoint().asURLRequest(encoder: encoder)
        #expect(request.httpBody == nil)
    }

    @Test("requestData는 본문을 그대로 싣는다")
    func requestData() throws {
        var endpoint = TestEndpoint()
        endpoint.method = .post
        endpoint.task = .requestData(Data("raw".utf8))

        let request = try endpoint.asURLRequest(encoder: encoder)

        #expect(request.httpBody == Data("raw".utf8))
    }

    @Test("requestJSONEncodable은 JSON 본문과 Content-Type을 만든다")
    func jsonEncodable() throws {
        struct Body: Codable, Equatable { let name: String; let count: Int }
        var endpoint = TestEndpoint()
        endpoint.method = .post
        endpoint.task = .requestJSONEncodable(Body(name: "challa", count: 3))

        let request = try endpoint.asURLRequest(encoder: encoder)

        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try JSONDecoder().decode(Body.self, from: #require(request.httpBody))
        #expect(body == Body(name: "challa", count: 3))
    }

    @Test("requestParameters(GET)는 쿼리스트링을 붙인다")
    func requestParametersQuery() throws {
        var endpoint = TestEndpoint()
        endpoint.path = "/search"
        endpoint.task = .requestParameters(parameters: ["q": "film"], encoding: URLEncoding.default)

        let request = try endpoint.asURLRequest(encoder: encoder)

        #expect(request.url?.absoluteString == "https://api.example.com/search?q=film")
    }

    @Test("requestQueryItems는 같은 키의 반복과 순서를 보존한다")
    func queryItemsRepeatedKeys() throws {
        var endpoint = TestEndpoint()
        endpoint.path = "/v1/rooms"
        endpoint.task = .requestQueryItems([
            URLQueryItem(name: "status", value: "SHOOTING"),
            URLQueryItem(name: "status", value: "PHOTO_PRINT_PENDING"),
            URLQueryItem(name: "status", value: "PHOTO_PRINT_COMPLETED")
        ])

        let request = try endpoint.asURLRequest(encoder: encoder)

        #expect(
            request.url?.absoluteString ==
                "https://api.example.com/v1/rooms"
                + "?status=SHOOTING&status=PHOTO_PRINT_PENDING&status=PHOTO_PRINT_COMPLETED"
        )
    }

    @Test("requestQueryItems는 URL에 이미 있던 쿼리 뒤에 덧붙인다")
    func queryItemsMergeWithExisting() throws {
        var endpoint = TestEndpoint()
        endpoint.baseURL = try #require(URL(string: "https://api.example.com/search?page=1"))
        endpoint.path = ""
        endpoint.task = .requestQueryItems([URLQueryItem(name: "size", value: "10")])

        let request = try endpoint.asURLRequest(encoder: encoder)

        #expect(request.url?.absoluteString == "https://api.example.com/search?page=1&size=10")
    }

    @Test("requestQueryItems는 예약 문자를 URLEncoding과 같은 규칙으로 이스케이프한다")
    func queryItemsEscaping() throws {
        var endpoint = TestEndpoint()
        endpoint.path = "/search"
        endpoint.task = .requestQueryItems([URLQueryItem(name: "q", value: "찰나+film&camera")])

        let request = try endpoint.asURLRequest(encoder: encoder)

        let query = try #require(request.url?.query(percentEncoded: true))
        #expect(query == "q=%EC%B0%B0%EB%82%98%2Bfilm%26camera")
    }

    @Test("requestQueryItems가 비어 있으면 URL이 그대로다")
    func queryItemsEmpty() throws {
        var endpoint = TestEndpoint()
        endpoint.path = "/v1/rooms"
        endpoint.task = .requestQueryItems([])

        let request = try endpoint.asURLRequest(encoder: encoder)

        #expect(request.url?.absoluteString == "https://api.example.com/v1/rooms")
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

        let request = try endpoint.asURLRequest(encoder: encoder)

        let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
        #expect(contentType.hasPrefix("multipart/form-data; boundary="))
        let httpBody = try #require(request.httpBody)
        let bodyString = try #require(String(data: httpBody, encoding: .utf8))
        #expect(bodyString.contains(#"Content-Disposition: form-data; name="photo"; filename="p.jpg""#))
        #expect(bodyString.contains("Content-Type: image/jpeg"))
        #expect(bodyString.contains("imgbytes"))
    }
}
