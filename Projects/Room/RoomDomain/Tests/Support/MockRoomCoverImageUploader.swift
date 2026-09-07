import Foundation
import os
import RoomDomain

final class MockRoomCoverImageUploader: RoomCoverImageUploader {

    private let uploaded = OSAllocatedUnfairLock<[Data]>(initialState: [])
    private let result: Result<URL, RoomError>

    init(result: Result<URL, RoomError> = .failure(.unknown)) {
        self.result = result
    }

    var uploadedData: [Data] {
        uploaded.withLock { $0 }
    }

    func upload(_ imageData: Data) async throws -> URL {
        uploaded.withLock { $0.append(imageData) }
        return try result.get()
    }
}
