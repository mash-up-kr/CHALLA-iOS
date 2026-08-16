import Foundation
import os
import PhotoDomain

/// 저장 요청을 캡처하는 `PhotoLibraryWriting` 목.
final class MockPhotoLibraryWriter: PhotoLibraryWriting {

    private let saved = OSAllocatedUnfairLock(initialState: [Data]())
    private let result: Result<Void, any Error>

    init(result: Result<Void, any Error> = .success(())) {
        self.result = result
    }

    /// 저장 요청된 바이트 (호출 순서대로).
    var savedData: [Data] {
        saved.withLock { $0 }
    }

    func save(imageData: Data) async throws {
        saved.withLock { $0.append(imageData) }
        try result.get()
    }
}
