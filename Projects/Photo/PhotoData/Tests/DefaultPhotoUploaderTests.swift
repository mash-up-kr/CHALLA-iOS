@testable import PhotoData
import CHALLANetwork
import Foundation
import PhotoDomain
import Testing

@Suite("DefaultPhotoUploader")
struct DefaultPhotoUploaderTests {

    private static let issueJSON = """
    {
      "success": true,
      "message": "ok",
      "data": {
        "upload": {
          "uploadUrl": "https://storage.test/photos/1?signature=abc",
          "imageUrl": "https://cdn.test/photos/1.jpg",
          "expiresInSeconds": 300
        }
      }
    }
    """

    private static let completeJSON = """
    { "success": true, "message": "ok", "data": { "photo": { "remainedPhotoCount": 5 } } }
    """

    @Test("발급 → 스토리지 PUT → 완료 통보 순서로 부르고 남은 장수를 돌려준다")
    func uploadsInThreeSteps() async throws {
        let client = MockHTTPClient.succeeding([Self.issueJSON, "", Self.completeJSON])
        let uploader = DefaultPhotoUploader(client: client)
        let jpeg = Data("jpeg-bytes".utf8)

        let remained = try await uploader.upload(jpegData: jpeg, roomID: 7, filterName: "Warm")

        #expect(remained == 5)
        #expect(client.requests.count == 3)

        let issue = client.requests[0]
        #expect(issue.path == "/api/v1/uploads")
        #expect(issue.method == .post)
        #expect(issue.usesBearerToken)

        let put = client.requests[1]
        #expect(put.method == .put)
        #expect(put.body == jpeg)
        #expect(!put.usesBearerToken) // Authorization을 붙이면 서명이 깨진다

        let complete = client.requests[2]
        #expect(complete.path == "/api/v1/photos")
        #expect(complete.method == .post)
        #expect(complete.usesBearerToken)
        let body = try #require(complete.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: [String: Any]])
        #expect(json["photo"]?["roomId"] as? Int64 == 7)
        #expect(json["photo"]?["cameraFilterName"] as? String == "Warm")
        #expect(json["photo"]?["imageUrl"] as? String == "https://cdn.test/photos/1.jpg")
    }

    @Test("스토리지 PUT이 실패하면 완료 통보를 부르지 않는다")
    func skipsCompletionWhenStoragePutFails() async {
        let client = MockHTTPClient(results: [
            .success(Response(statusCode: 200, data: Data(Self.issueJSON.utf8))),
            .success(Response(statusCode: 403, data: Data())) // 서명 만료 등
        ])
        let uploader = DefaultPhotoUploader(client: client)

        await #expect(throws: (any Error).self) {
            _ = try await uploader.upload(jpegData: Data(), roomID: 7, filterName: "Warm")
        }
        #expect(client.requests.count == 2) // 완료 통보(3번째)가 없어야 한다
    }

    @Test("완료 통보의 409는 장수 소진으로 번역된다")
    func mapsConflictToPhotoExhausted() async {
        let client = MockHTTPClient(results: [
            .success(Response(statusCode: 200, data: Data(Self.issueJSON.utf8))),
            .success(Response(statusCode: 200, data: Data())),
            .success(Response(statusCode: 409, data: Data()))
        ])
        let uploader = DefaultPhotoUploader(client: client)

        await #expect(throws: PhotoError.photoExhausted) {
            _ = try await uploader.upload(jpegData: Data(), roomID: 7, filterName: "Warm")
        }
    }
}
