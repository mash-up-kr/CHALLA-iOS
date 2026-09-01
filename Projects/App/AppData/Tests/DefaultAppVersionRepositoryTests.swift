@testable import AppData
import AppDomain
import CHALLANetwork
import Foundation
import Testing

@Suite("DefaultAppVersionRepository")
struct DefaultAppVersionRepositoryTests {

    private static func versionJSON(
        updateRequired: Bool,
        storeUrl: String = "https://apps.apple.com/kr/app/id123"
    ) -> String {
        """
        {
          "success": true,
          "message": "ok",
          "data": {
            "app": {
              "updateRequired": \(updateRequired),
              "updateAvailable": true,
              "latestVersion": "9.9.9",
              "storeUrl": "\(storeUrl)"
            }
          }
        }
        """
    }

    @Test("os=IOS·현재 버전을 쿼리로 싣고 토큰 없이 GET한다")
    func requestsWithOSAndVersionQueryWithoutToken() async throws {
        let client = MockHTTPClient.returning(json: Self.versionJSON(updateRequired: false))
        let repository = DefaultAppVersionRepository(client: client)

        _ = try await repository.checkUpdateRequirement(currentVersion: "1.2.3")

        let request = try #require(client.requests.first)
        #expect(request.path == "/api/v1/app/version")
        #expect(request.method == .get)
        #expect(!request.usesBearerToken) // 로그인 전(스플래시)에 부른다
        #expect(request.queryItems == [
            URLQueryItem(name: "os", value: "IOS"),
            URLQueryItem(name: "version", value: "1.2.3")
        ])
    }

    @Test("updateRequired=false면 통과다")
    func mapsNotRequired() async throws {
        let client = MockHTTPClient.returning(json: Self.versionJSON(updateRequired: false))
        let repository = DefaultAppVersionRepository(client: client)

        let requirement = try await repository.checkUpdateRequirement(currentVersion: "1.2.3")

        #expect(requirement == .notRequired)
    }

    @Test("updateRequired=true면 응답의 스토어 주소를 실은 강제 업데이트다")
    func mapsForcedWithStoreURL() async throws {
        let client = MockHTTPClient.returning(json: Self.versionJSON(updateRequired: true))
        let repository = DefaultAppVersionRepository(client: client)

        let requirement = try await repository.checkUpdateRequirement(currentVersion: "1.0.0")

        #expect(requirement == .forced(storeURL: URL(string: "https://apps.apple.com/kr/app/id123")))
    }

    @Test("스토어 주소가 URL이 안 되는 문자열이면 nil로 접는다 — 화면은 막되 '확인'은 아무 것도 안 연다")
    func foldsMalformedStoreURLToNil() async throws {
        let client = MockHTTPClient.returning(json: Self.versionJSON(updateRequired: true, storeUrl: ""))
        let repository = DefaultAppVersionRepository(client: client)

        let requirement = try await repository.checkUpdateRequirement(currentVersion: "1.0.0")

        #expect(requirement == .forced(storeURL: nil))
    }

    @Test("success=false 응답은 던진다 — fail-open 처리는 호출부 몫이다")
    func throwsOnServerRejection() async {
        let client = MockHTTPClient.returning(
            json: #"{ "success": false, "message": "unsupported os", "data": null }"#
        )
        let repository = DefaultAppVersionRepository(client: client)

        await #expect(throws: (any Error).self) {
            _ = try await repository.checkUpdateRequirement(currentVersion: "1.0.0")
        }
    }
}
