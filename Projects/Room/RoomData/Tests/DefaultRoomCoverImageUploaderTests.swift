@testable import RoomData
import CHALLANetwork
import Foundation
import RoomDomain
import Testing

@Suite("DefaultRoomCoverImageUploader")
struct DefaultRoomCoverImageUploaderTests {

    private static let issuedJSON = """
    {"success":true,"message":"OK","data":{"upload":{
      "uploadUrl":"https://s3.example.com/put?sig=abc","imageUrl":"https://cdn.example.com/cover.jpg","expiresInSeconds":300
    }}}
    """

    private static let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])

    @Test("발급 요청 뒤 서명 URL로 직접 올리고 공개 URL을 돌려준다")
    func uploadsThenReturnsPublicURL() async throws {
        let client = MockHTTPClient.succeeding([Self.issuedJSON, ""])

        let url = try await DefaultRoomCoverImageUploader(client: client).upload(Self.jpeg)

        #expect(url == URL(string: "https://cdn.example.com/cover.jpg"))
        #expect(client.requests.count == 2)

        let issue = try #require(client.requests.first)
        #expect(issue.path == "/api/v1/uploads")
        #expect(issue.method == .post)
        #expect(issue.usesBearerToken)

        let put = try #require(client.requests.last)
        #expect(put.method == .put)
        #expect(put.usesBearerToken == false) // Authorization이 붙으면 서명이 깨진다
        #expect(put.headers["Content-Type"] == "image/jpeg")
    }

    @Test("발급 본문은 purpose ROOM_COVER_IMAGE와 image/jpeg를 upload 키 아래에 싣는다")
    func issueRequestCarriesContractedBody() async throws {
        let client = MockHTTPClient.succeeding([Self.issuedJSON, ""])

        _ = try await DefaultRoomCoverImageUploader(client: client).upload(Self.jpeg)

        let body = try #require(client.requests.first?.body)
        let root = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let upload = try #require(root["upload"] as? [String: Any])
        #expect(upload["purpose"] as? String == "ROOM_COVER_IMAGE")
        #expect(upload["contentType"] as? String == "image/jpeg")
    }

    @Test("받은 바이트를 재인코딩 없이 그대로 올린다")
    func uploadsBytesAsIs() async throws {
        let client = MockHTTPClient.succeeding([Self.issuedJSON, ""])

        _ = try await DefaultRoomCoverImageUploader(client: client).upload(Self.jpeg)

        #expect(client.requests.last?.body == Self.jpeg)
    }

    @Test("발급 실패(success:false)는 RoomError.server로 정규화된다")
    func issueFailureIsNormalized() async {
        let client = MockHTTPClient.returning(json: #"{"success":false,"message":"권한 없음","data":null}"#)

        await #expect(throws: RoomError.server(message: "권한 없음")) {
            _ = try await DefaultRoomCoverImageUploader(client: client).upload(Self.jpeg)
        }
        #expect(client.requests.count == 1)
    }

    @Test("스토리지 업로드가 403이면 RoomError.server로 정규화된다")
    func storageRejectionIsNormalized() async {
        let client = MockHTTPClient(results: [
            .success(Response(statusCode: 200, data: Data(Self.issuedJSON.utf8))),
            .success(Response(statusCode: 403, data: Data()))
        ])

        await #expect(throws: RoomError.server(message: "요청이 실패했어요. (HTTP 403)")) {
            _ = try await DefaultRoomCoverImageUploader(client: client).upload(Self.jpeg)
        }
    }

    @Test("전송 실패는 .network로 정규화된다")
    func transportFailureIsNormalized() async {
        let client = MockHTTPClient.failing(NetworkError.transport(underlying: URLError(.notConnectedToInternet)))

        await #expect(throws: RoomError.network) {
            _ = try await DefaultRoomCoverImageUploader(client: client).upload(Self.jpeg)
        }
    }
}

@Suite("UploadEndpoint")
struct UploadEndpointTests {

    @Test("put — 발급받은 서명 URL을 그대로 쓰고 경로를 덧붙이지 않는다")
    func putUsesSignedURLAsIs() throws {
        let signed = try #require(URL(string: "https://s3.example.com/put?sig=abc"))
        let endpoint = UploadEndpoint.put(url: signed, data: Data(), contentType: "image/jpeg")

        #expect(endpoint.baseURL == signed)
        #expect(endpoint.path.isEmpty)
    }
}
