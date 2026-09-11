@testable import PhotoData
import CHALLANetwork
import CHALLANetworkTesting
import CoreGraphics
import Foundation
import ImageIO
import PhotoDomain
import Testing
import UIKit

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

    /// 축소본 주소까지 내려주는 발급 응답 (`purpose`가 `PHOTO`일 때).
    private static let thumbnailIssueJSON = """
    {
      "success": true,
      "message": "ok",
      "data": {
        "upload": {
          "uploadUrl": "https://storage.test/photos/1?signature=abc",
          "imageUrl": "https://cdn.test/photos/1.jpg",
          "thumbnailUploadUrl": "https://storage.test/photos/1_thumbnail?signature=def",
          "thumbnailImageUrl": "https://cdn.test/photos/1_thumbnail.jpg",
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

    @Test("5MB를 넘는 촬영본은 5MB 이하로 압축해서 올린다")
    func compressesOversizedPhotoBeforePut() async throws {
        let client = MockHTTPClient.succeeding([Self.issueJSON, "", Self.completeJSON])
        let uploader = DefaultPhotoUploader(client: client)
        let maxUploadBytes = 5 * 1024 * 1024
        let oversized = try Self.noiseJPEGData(pixelWidth: 2400, pixelHeight: 2400)
        try #require(oversized.count > maxUploadBytes)

        _ = try await uploader.upload(jpegData: oversized, roomID: 7, filterName: "Warm")

        let body = try #require(client.requests[1].body)
        #expect(body.count <= maxUploadBytes)
        // 압축본도 여전히 디코딩 가능한 JPEG이어야 한다
        let source = try #require(CGImageSourceCreateWithData(body as CFData, nil))
        #expect(CGImageSourceGetType(source) == "public.jpeg" as CFString)
    }

    /// JPEG 압축이 안 먹히는 노이즈 픽셀로 5MB 초과 픽스처를 만든다 (고정 시드 LCG — 결정적).
    private static func noiseJPEGData(pixelWidth: Int, pixelHeight: Int) throws -> Data {
        var pixels = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * 4)
        var seed: UInt64 = 0x5DEE_CE66
        for index in stride(from: 0, to: pixels.count, by: 4) {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            pixels[index] = UInt8(truncatingIfNeeded: seed >> 33)
            pixels[index + 1] = UInt8(truncatingIfNeeded: seed >> 41)
            pixels[index + 2] = UInt8(truncatingIfNeeded: seed >> 49)
            pixels[index + 3] = 255
        }
        let context = pixels.withUnsafeMutableBytes { buffer in
            CGContext(
                data: buffer.baseAddress,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: pixelWidth * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        }
        guard let cgImage = context?.makeImage(),
              let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 1.0)
        else {
            throw NoiseFixtureFailure.encodingFailed
        }
        return data
    }

    private enum NoiseFixtureFailure: Error {
        case encodingFailed
    }

    // MARK: - 축소본

    @Test("축소본 주소가 오면 원본과 축소본을 모두 올리고 완료 통보에 축소본 주소를 싣는다")
    func uploadsThumbnailAlongsideOriginal() async throws {
        let client = MockHTTPClient.succeeding([Self.thumbnailIssueJSON, "", "", Self.completeJSON])
        let uploader = DefaultPhotoUploader(client: client)
        let jpeg = try Self.noiseJPEGData(pixelWidth: 900, pixelHeight: 900)

        _ = try await uploader.upload(jpegData: jpeg, roomID: 7, filterName: "Warm")

        #expect(client.requests.count == 4)

        // 원본이 먼저다 — 축소본 PUT이 실패해도 사진은 이미 스토리지에 있어야 한다.
        #expect(client.requests[1].body == jpeg)

        let thumbnailPut = client.requests[2]
        #expect(thumbnailPut.method == .put)
        #expect(!thumbnailPut.usesBearerToken) // 서명 URL에 Authorization을 붙이면 403이 난다
        let thumbnailBody = try #require(thumbnailPut.body)
        #expect(thumbnailBody.count < jpeg.count)

        // 긴 변이 상한(400px) 이하로 줄어 있어야 한다.
        let source = try #require(CGImageSourceCreateWithData(thumbnailBody as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        #expect(max(width, height) <= 400)

        let body = try #require(client.requests[3].body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: [String: Any]])
        #expect(json["photo"]?["thumbnailImageUrl"] as? String == "https://cdn.test/photos/1_thumbnail.jpg")
    }

    @Test("축소본 PUT이 실패해도 업로드는 끝나고, 완료 통보에서 축소본 주소만 빠진다")
    func completesWithoutThumbnailWhenThumbnailPutFails() async throws {
        let client = MockHTTPClient(results: [
            .success(Response(statusCode: 200, data: Data(Self.thumbnailIssueJSON.utf8))),
            .success(Response(statusCode: 200, data: Data())),
            .success(Response(statusCode: 403, data: Data())), // 축소본만 실패
            .success(Response(statusCode: 200, data: Data(Self.completeJSON.utf8)))
        ])
        let uploader = DefaultPhotoUploader(client: client)
        let jpeg = try Self.noiseJPEGData(pixelWidth: 900, pixelHeight: 900)

        let remained = try await uploader.upload(jpegData: jpeg, roomID: 7, filterName: "Warm")

        #expect(remained == 5)
        #expect(client.requests.count == 4)
        let body = try #require(client.requests[3].body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: [String: Any]])
        #expect(json["photo"]?["thumbnailImageUrl"] == nil)
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
