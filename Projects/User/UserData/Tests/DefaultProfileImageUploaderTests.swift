@testable import UserData
import CHALLANetwork
import CHALLANetworkTesting
import Foundation
import Testing
import UIKit
import UserDomain

@Suite("DefaultProfileImageUploader")
struct DefaultProfileImageUploaderTests {

    private static let issuedJSON = """
    {"success":true,"message":"OK","data":{"upload":{
      "uploadUrl":"https://s3.example.com/put?sig=abc","imageUrl":"https://cdn.example.com/p.jpg","expiresInSeconds":300
    }}}
    """

    /// UIImage로 디코딩 가능한 실제 PNG — 업로더가 JPEG로 다시 인코딩할 입력이다.
    private static var sampleImageData: Data {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    @Test("성공 — 발급 요청 후 서명 URL로 직접 올리고 공개 URL을 돌려준다")
    func uploadsThenReturnsPublicURL() async throws {
        let client = MockHTTPClient.succeeding([Self.issuedJSON, ""])

        let url = try await DefaultProfileImageUploader(client: client).upload(Self.sampleImageData)

        #expect(url == URL(string: "https://cdn.example.com/p.jpg"))
        #expect(client.requests.count == 2)

        let issue = try #require(client.requests.first)
        #expect(issue.path == "/api/v1/uploads")
        #expect(issue.method == .post)
        #expect(issue.usesBearerToken)

        let put = try #require(client.requests.last)
        #expect(put.method == .put)
        // 서명이 깨지지 않도록 Authorization을 붙이지 않고, Content-Type은 발급 때와 같아야 한다.
        #expect(put.usesBearerToken == false)
        #expect(put.headers["Content-Type"] == "image/jpeg")
    }

    @Test("발급 요청 본문 — upload 키로 감싸 purpose·contentType을 싣는다")
    func issueRequestCarriesContractedBody() async throws {
        let client = MockHTTPClient.succeeding([Self.issuedJSON, ""])

        _ = try await DefaultProfileImageUploader(client: client).upload(Self.sampleImageData)

        let body = try #require(client.requests.first?.body)
        let root = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let upload = try #require(root["upload"] as? [String: Any])
        #expect(upload["purpose"] as? String == "PROFILE_IMAGE")
        #expect(upload["contentType"] as? String == "image/jpeg")
    }

    @Test("HEIC 등 다른 포맷도 JPEG로 다시 인코딩해 올린다")
    func reencodesToJPEG() async throws {
        let client = MockHTTPClient.succeeding([Self.issuedJSON, ""])

        _ = try await DefaultProfileImageUploader(client: client).upload(Self.sampleImageData)

        let sent = try #require(client.requests.last?.body)
        #expect(sent.starts(with: [0xFF, 0xD8, 0xFF])) // JPEG SOI 마커
    }

    @Test("이미지로 읽을 수 없는 데이터는 발급 요청 전에 막힌다")
    func undecodableDataFailsBeforeIssuing() async {
        let client = MockHTTPClient.succeeding([Self.issuedJSON, ""])

        await #expect(throws: UserError.unknown) {
            _ = try await DefaultProfileImageUploader(client: client).upload(Data("not an image".utf8))
        }
        #expect(client.requests.isEmpty)
    }

    @Test("발급 실패(success:false)는 UserError.server로 정규화된다")
    func issueFailureIsNormalized() async {
        let client = MockHTTPClient.returning(json: #"{"success":false,"message":"권한 없음","data":null}"#)

        await #expect(throws: UserError.server(message: "권한 없음")) {
            _ = try await DefaultProfileImageUploader(client: client).upload(Self.sampleImageData)
        }
    }

    @Test("스토리지 업로드가 403이면 UserError.server로 정규화된다")
    func storageRejectionIsNormalized() async {
        let client = MockHTTPClient(results: [
            .success(Response(statusCode: 200, data: Data(Self.issuedJSON.utf8))),
            .success(Response(statusCode: 403, data: Data()))
        ])

        await #expect(throws: UserError.server(message: "요청이 실패했어요. (HTTP 403)")) {
            _ = try await DefaultProfileImageUploader(client: client).upload(Self.sampleImageData)
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
        #expect(endpoint.path.isEmpty) // 쿼리까지 서명에 포함되므로 손대면 403이 난다
    }
}
