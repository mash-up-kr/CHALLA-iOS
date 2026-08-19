import Foundation
import PhotoDomain

/// 데모·테스트용 가짜 필터 저장소. 넘겨준 목록과 LUT 데이터를 그대로 돌려준다.
public struct InMemoryCameraFilterRepository: CameraFilterRepository {

    private let storedFilters: [CameraFilter]
    /// 필터 이름 → .cube 원본 바이트. 없는 이름을 조회하면 무필터 통과가 되도록 빈 데이터를 준다.
    private let lutDataByName: [String: Data]
    private let latency: Duration
    private let failure: PhotoError?

    public init(
        filters: [CameraFilter],
        lutDataByName: [String: Data] = [:],
        latency: Duration = .zero,
        failure: PhotoError? = nil
    ) {
        storedFilters = filters
        self.lutDataByName = lutDataByName
        self.latency = latency
        self.failure = failure
    }

    public func filters() async throws -> [CameraFilter] {
        try await waitAndCheckFailure()
        return storedFilters
    }

    public func lutData(for filter: CameraFilter) async throws -> Data {
        try await waitAndCheckFailure()
        return lutDataByName[filter.name] ?? Data()
    }

    private func waitAndCheckFailure() async throws {
        if latency > .zero {
            try await Task.sleep(for: latency)
        }
        if let failure {
            throw failure
        }
    }
}
