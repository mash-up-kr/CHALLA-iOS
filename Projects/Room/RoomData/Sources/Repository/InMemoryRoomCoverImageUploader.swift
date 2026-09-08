import Foundation
import RoomDomain

public struct InMemoryRoomCoverImageUploader: RoomCoverImageUploader {

    private let failure: RoomError?

    public init(failure: RoomError? = nil) {
        self.failure = failure
    }

    public func upload(_: Data) async throws -> URL {
        if let failure {
            throw failure
        }
        guard let url = URL(string: "https://example.com/cover/\(UUID().uuidString).jpg") else {
            throw RoomError.unknown
        }
        return url
    }
}
