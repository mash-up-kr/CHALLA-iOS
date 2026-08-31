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
        let isOn: Bool
    }

    private struct State {
        var requestedRoomIDs: [Int64] = []
        var reactionsForPhotoIDs: [String] = []
        var reactionCalls: [ReactionCall] = []
        var imageDataRequests: [String] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let photosResult: Result<[Photo], PhotoError>
    private let reactionsResult: Result<PhotoReactions, PhotoError>
    /// setReaction은 값을 돌려주지 않으므로 성공/실패만 지정한다.
    private let reactionResult: Result<Void, PhotoError>
    private let imageDataResult: Result<Data, PhotoError>

    init(
        photosResult: Result<[Photo], PhotoError> = .success([]),
        reactionsResult: Result<PhotoReactions, PhotoError> = .success(PhotoReactions()),
        reactionResult: Result<Void, PhotoError> = .success(()),
        imageDataResult: Result<Data, PhotoError> = .failure(.unknown)
    ) {
        self.photosResult = photosResult
        self.reactionsResult = reactionsResult
        self.reactionResult = reactionResult
        self.imageDataResult = imageDataResult
    }

    // MARK: - 검증용 프로퍼티

    var requestedRoomIDs: [Int64] {
        state.withLock { $0.requestedRoomIDs }
    }

    /// reactions(forPhotoID:)에 전달된 사진 ID (호출 순서대로).
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

    // MARK: - PhotoRepository

    func photos(inRoom roomID: Int64) async throws -> [Photo] {
        state.withLock { $0.requestedRoomIDs.append(roomID) }
        return try photosResult.get()
    }

    func reactions(forPhotoID photoID: String) async throws -> PhotoReactions {
        state.withLock { $0.reactionsForPhotoIDs.append(photoID) }
        return try reactionsResult.get()
    }

    func setReaction(roomID: Int64, photoID: String, kind: ReactionKind, isOn: Bool) async throws {
        state.withLock {
            $0.reactionCalls.append(ReactionCall(roomID: roomID, photoID: photoID, kind: kind, isOn: isOn))
        }
        try reactionResult.get()
    }

    func imageData(for photo: Photo) async throws -> Data {
        state.withLock { $0.imageDataRequests.append(photo.id) }
        return try imageDataResult.get()
    }
}
