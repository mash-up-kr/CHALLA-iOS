import CHALLANetwork
import Foundation
import os
import PhotoDomain

/// `CameraFilterRepository`의 실서버 구현. 목록은 서버에서, LUT 파일은 스토리지 공개 URL에서 받는다.
public struct DefaultCameraFilterRepository: CameraFilterRepository {

    private let client: any HTTPClient
    private let lutCache = LUTCache()

    public init(client: any HTTPClient) {
        self.client = client
    }

    public func filters() async throws -> [CameraFilter] {
        do {
            let response = try await client.request(
                ShootEndpoint.cameraFilters,
                as: BaseResponseDTO<CameraFiltersResponseDTO>.self
            )
            return try response.unwrap().shoot.cameraFilters.map { dto in
                guard let fileURL = URL(string: dto.fileUrl) else {
                    throw PhotoError.unknown
                }
                return CameraFilter(name: dto.name, fileURL: fileURL)
            }
        } catch {
            throw PhotoError.normalized(error)
        }
    }

    public func lutData(for filter: CameraFilter) async throws -> Data {
        if let cached = lutCache.data(for: filter.fileURL) {
            return cached
        }
        do {
            let response = try await client
                .request(ShootEndpoint.cubeFile(filter.fileURL))
                .filterSuccessfulStatusCodes()
            lutCache.store(response.data, for: filter.fileURL)
            return response.data
        } catch {
            throw PhotoError.normalized(error)
        }
    }
}

/// LUT 파일은 만료되지 않는 공개 URL이라 앱 세션 동안 메모리에 붙잡아 재다운로드를 막는다.
/// (파일당 수백 KB × 10종 수준 — 디스크 캐시까지 갈 크기가 아니다.)
private final class LUTCache: Sendable {

    private let storage = OSAllocatedUnfairLock<[URL: Data]>(initialState: [:])

    func data(for url: URL) -> Data? {
        storage.withLock { $0[url] }
    }

    func store(_ data: Data, for url: URL) {
        storage.withLock { $0[url] = data }
    }
}
