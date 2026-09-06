import Foundation
import os
import PhotoDomain

/// 호출을 캡처하고 지정한 결과를 돌려주는 `PhotoRepository` 목.
///
/// `PhotoRepository: Sendable`을 `@unchecked` 없이 만족시키려고 가변 상태를 락으로 감싼다
/// (iOS 17 타깃이라 `Mutex` 대신 `OSAllocatedUnfairLock`).
final class MockPhotoRepository: PhotoRepository {

    /// 리액션 요청 한 건의 인자.
    struct ReactionCall: Equatable {
        let roomID: Int64
        let photoID: String
        let kind: ReactionKind
    }

    private struct State {
        var requestedRoomIDs: [Int64] = []
        var reactionsForPhotoIDs: [String] = []
        var reactionsRoomIDs: [Int64] = []
        var reactionCalls: [ReactionCall] = []
        var deletedChatIDs: [Int64] = []
        var imageDataRequests: [String] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let photosResult: Result<[Photo], PhotoError>
    private let reactionsResult: Result<PhotoReactions, PhotoError>
    /// setReaction의 성공/실패.
    private let reactionResult: Result<Void, PhotoError>
    /// setReaction이 성공했을 때 돌려줄 채팅 id.
    private let createdChatID: Int64?
    private let deleteReactionResult: Result<Void, PhotoError>
    private let imageDataResult: Result<Data, PhotoError>

    init(
        photosResult: Result<[Photo], PhotoError> = .success([]),
        reactionsResult: Result<PhotoReactions, PhotoError> = .success(PhotoReactions()),
        reactionResult: Result<Void, PhotoError> = .success(()),
        createdChatID: Int64? = nil,
        deleteReactionResult: Result<Void, PhotoError> = .success(()),
        imageDataResult: Result<Data, PhotoError> = .failure(.unknown)
    ) {
        self.photosResult = photosResult
        self.reactionsResult = reactionsResult
        self.reactionResult = reactionResult
        self.createdChatID = createdChatID
        self.deleteReactionResult = deleteReactionResult
        self.imageDataResult = imageDataResult
    }

    // MARK: - 검증용 프로퍼티

    var requestedRoomIDs: [Int64] {
        state.withLock { $0.requestedRoomIDs }
    }

    /// reactions(inRoom:photoID:)에 전달된 방 ID (호출 순서대로).
    var reactionsRoomIDs: [Int64] {
        state.withLock { $0.reactionsRoomIDs }
    }

    /// reactions(inRoom:photoID:)에 전달된 사진 ID (호출 순서대로).
    var reactionsForPhotoIDs: [String] {
        state.withLock { $0.reactionsForPhotoIDs }
    }

    /// setReaction에 전달된 인자 (호출 순서대로).
    var reactionCalls: [ReactionCall] {
        state.withLock { $0.reactionCalls }
    }

    var imageDataRequests: [String] {
        state.withLock { $0.imageDataRequests }
    }

    /// deleteReaction에 전달된 채팅 id (호출 순서대로).
    var deletedChatIDs: [Int64] {
        state.withLock { $0.deletedChatIDs }
    }

    // MARK: - PhotoRepository

    func photos(inRoom roomID: Int64) async throws -> [Photo] {
        state.withLock { $0.requestedRoomIDs.append(roomID) }
        return try photosResult.get()
    }

    func reactions(inRoom roomID: Int64, photoID: String) async throws -> PhotoReactions {
        state.withLock {
            $0.reactionsForPhotoIDs.append(photoID)
            $0.reactionsRoomIDs.append(roomID)
        }
        return try reactionsResult.get()
    }

    @discardableResult
    func setReaction(roomID: Int64, photoID: String, kind: ReactionKind) async throws -> Int64? {
        state.withLock {
            $0.reactionCalls.append(ReactionCall(roomID: roomID, photoID: photoID, kind: kind))
        }
        try reactionResult.get()
        return createdChatID
    }

    func deleteReaction(chatID: Int64) async throws {
        state.withLock { $0.deletedChatIDs.append(chatID) }
        try deleteReactionResult.get()
    }

    func imageData(for photo: Photo) async throws -> Data {
        state.withLock { $0.imageDataRequests.append(photo.id) }
        return try imageDataResult.get()
    }

    func imageDataStream(for photos: [Photo]) -> AsyncStream<Result<Data, PhotoError>> {
        state.withLock { $0.imageDataRequests.append(contentsOf: photos.map(\.id)) }
        let result = imageDataResult

        return AsyncStream { continuation in
            for _ in photos {
                continuation.yield(result)
            }
            continuation.finish()
        }
    }
}
