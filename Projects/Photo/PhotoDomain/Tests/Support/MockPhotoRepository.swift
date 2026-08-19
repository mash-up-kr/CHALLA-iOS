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
        let photoID: String
        let kind: ReactionKind
        let isOn: Bool
    }

    private struct State {
        var requestedRoomIDs: [Int64] = []
        var reactionCalls: [ReactionCall] = []
        var imageDataRequests: [String] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let photosResult: Result<[Photo], PhotoError>
    private let reactionResult: Result<Photo, PhotoError>
    private let imageDataResult: Result<Data, PhotoError>

    init(
        photosResult: Result<[Photo], PhotoError> = .success([]),
        reactionResult: Result<Photo, PhotoError> = .failure(.unknown),
        imageDataResult: Result<Data, PhotoError> = .failure(.unknown)
    ) {
        self.photosResult = photosResult
        self.reactionResult = reactionResult
        self.imageDataResult = imageDataResult
    }

    // MARK: - 검증용 프로퍼티

    var requestedRoomIDs: [Int64] {
        state.withLock { $0.requestedRoomIDs }
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

    func setReaction(photoID: String, kind: ReactionKind, isOn: Bool) async throws -> Photo {
        state.withLock { $0.reactionCalls.append(ReactionCall(photoID: photoID, kind: kind, isOn: isOn)) }
        return try reactionResult.get()
    }

    func imageData(for photo: Photo) async throws -> Data {
        state.withLock { $0.imageDataRequests.append(photo.id) }
        return try imageDataResult.get()
    }
}
