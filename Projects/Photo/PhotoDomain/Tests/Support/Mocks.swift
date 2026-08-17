import Foundation
import os
import PhotoDomain

/// 호출을 캡처하고 지정한 결과를 돌려주는 `CameraFilterRepository` 목 (`MockRoomRepository`와 같은 방식).
final class MockCameraFilterRepository: CameraFilterRepository {

    private struct State {
        var filtersCallCount = 0
        var lutRequests: [CameraFilter] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let filtersResult: Result<[CameraFilter], PhotoError>
    private let lutDataResult: Result<Data, PhotoError>

    init(
        filtersResult: Result<[CameraFilter], PhotoError> = .failure(.unknown),
        lutDataResult: Result<Data, PhotoError> = .failure(.unknown)
    ) {
        self.filtersResult = filtersResult
        self.lutDataResult = lutDataResult
    }

    var filtersCallCount: Int {
        state.withLock { $0.filtersCallCount }
    }

    var lutRequests: [CameraFilter] {
        state.withLock { $0.lutRequests }
    }

    func filters() async throws -> [CameraFilter] {
        state.withLock { $0.filtersCallCount += 1 }
        return try filtersResult.get()
    }

    func lutData(for filter: CameraFilter) async throws -> Data {
        state.withLock { $0.lutRequests.append(filter) }
        return try lutDataResult.get()
    }
}

/// 업로드 인자를 캡처하고 지정한 결과를 돌려주는 `PhotoUploader` 목.
final class MockPhotoUploader: PhotoUploader {

    struct Upload: Equatable {
        let jpegData: Data
        let roomID: Int64
        let filterName: String
    }

    private let state = OSAllocatedUnfairLock<[Upload]>(initialState: [])
    private let result: Result<Int, PhotoError>

    init(result: Result<Int, PhotoError> = .failure(.unknown)) {
        self.result = result
    }

    var uploads: [Upload] {
        state.withLock { $0 }
    }

    func upload(jpegData: Data, roomID: Int64, filterName: String) async throws -> Int {
        state.withLock { $0.append(Upload(jpegData: jpegData, roomID: roomID, filterName: filterName)) }
        return try result.get()
    }
}
