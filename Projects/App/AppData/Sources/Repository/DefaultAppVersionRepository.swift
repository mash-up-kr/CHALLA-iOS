import AppDomain
import CHALLANetwork
import Foundation

/// `AppVersionRepository`의 실서버 구현 — `GET /api/v1/app/version`.
public struct DefaultAppVersionRepository: AppVersionRepository {

    private let client: any HTTPClient

    public init(client: any HTTPClient) {
        self.client = client
    }

    public func checkUpdateRequirement(currentVersion: String) async throws -> AppUpdateRequirement {
        let app = try await client.request(
            AppEndpoint.version(currentVersion: currentVersion),
            as: BaseResponseDTO<AppVersionResponseDTO>.self
        ).unwrap().app

        guard app.updateRequired else { return .notRequired }
        return .forced(storeURL: URL(string: app.storeUrl))
    }
}
