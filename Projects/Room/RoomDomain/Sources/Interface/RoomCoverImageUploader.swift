import Foundation

public protocol RoomCoverImageUploader: Sendable {

    func upload(_ imageData: Data) async throws -> URL
}
