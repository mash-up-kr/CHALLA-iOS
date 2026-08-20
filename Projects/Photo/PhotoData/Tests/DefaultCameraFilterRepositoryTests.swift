@testable import PhotoData
import CHALLANetwork
import Foundation
import PhotoDomain
import Testing

@Suite("DefaultCameraFilterRepository")
struct DefaultCameraFilterRepositoryTests {

    private static let filtersJSON = """
    {
      "success": true,
      "message": "ok",
      "data": {
        "shoot": {
          "cameraFilters": [
            { "name": "Black", "fileUrl": "https://cdn.test/black.cube" },
            { "name": "Warm", "fileUrl": "https://cdn.test/warm.cube" }
          ]
        }
      }
    }
    """

    @Test("필터 목록을 받아 도메인 필터로 돌려준다")
    func fetchesFilters() async throws {
        let client = MockHTTPClient.returning(json: Self.filtersJSON)
        let repository = DefaultCameraFilterRepository(client: client)

        let filters = try await repository.filters()

        #expect(filters.map(\.name) == ["Black", "Warm"])
        #expect(filters.map(\.fileURL.absoluteString) == [
            "https://cdn.test/black.cube", "https://cdn.test/warm.cube"
        ])
        let request = try #require(client.requests.first)
        #expect(request.path == "/api/v1/shoots/camera-filters")
        #expect(request.method == .get)
        #expect(request.usesBearerToken)
    }

    @Test("success가 false면 서버 메시지를 담아 던진다")
    func unwrapsFailureEnvelope() async {
        let client = MockHTTPClient.returning(
            json: #"{ "success": false, "message": "점검 중", "data": null }"#
        )
        let repository = DefaultCameraFilterRepository(client: client)

        await #expect(throws: PhotoError.server(message: "점검 중")) {
            _ = try await repository.filters()
        }
    }

    @Test("LUT 파일은 토큰 없이 받아오고, 같은 필터는 다시 내려받지 않는다")
    func downloadsAndCachesLUT() async throws {
        let cube = Data("LUT_3D_SIZE 2".utf8)
        let client = MockHTTPClient(result: .success(Response(statusCode: 200, data: cube)))
        let repository = DefaultCameraFilterRepository(client: client)
        let filter = try CameraFilter(name: "Black", fileURL: #require(URL(string: "https://cdn.test/black.cube")))

        let first = try await repository.lutData(for: filter)
        let second = try await repository.lutData(for: filter)

        #expect(first == cube)
        #expect(second == cube)
        #expect(client.requests.count == 1) // 두 번째는 캐시
        let request = try #require(client.requests.first)
        #expect(!request.usesBearerToken)
    }

    @Test("전송 실패는 PhotoError.network로 정규화된다")
    func normalizesTransportError() async throws {
        let client = MockHTTPClient.failing(
            NetworkError.transport(underlying: URLError(.notConnectedToInternet))
        )
        let repository = DefaultCameraFilterRepository(client: client)
        let filter = try CameraFilter(name: "Black", fileURL: #require(URL(string: "https://cdn.test/black.cube")))

        await #expect(throws: PhotoError.network) {
            _ = try await repository.lutData(for: filter)
        }
    }
}
