import Foundation
import os
import RoomDomain

/// 호출을 캡처하고 지정한 결과를 돌려주는 `RoomRepository` 목.
///
/// `RoomRepository` 규약대로 실패는 항상 `RoomError`로 던진다.
/// `RoomRepository: Sendable`을 `@unchecked` 없이 만족시키기 위해 가변 상태를
/// 락으로 감싼다 (`MockAuthRepository`와 같은 방식 — iOS 17 타깃이라 `OSAllocatedUnfairLock`).
final class MockRoomRepository: RoomRepository {

    private struct State {
        var roomsCallCount = 0
        var createdDrafts: [RoomDraft] = []
        var joinedCodes: [String] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let roomsResult: Result<[Room], RoomError>
    private let createResult: Result<Room, RoomError>
    private let joinResult: Result<Room, RoomError>

    init(
        roomsResult: Result<[Room], RoomError> = .failure(.unknown),
        createResult: Result<Room, RoomError> = .failure(.unknown),
        joinResult: Result<Room, RoomError> = .failure(.unknown)
    ) {
        self.roomsResult = roomsResult
        self.createResult = createResult
        self.joinResult = joinResult
    }

    // MARK: - 검증용 프로퍼티

    /// rooms() 호출 횟수.
    var roomsCallCount: Int {
        state.withLock { $0.roomsCallCount }
    }

    /// createRoom에 전달된 draft (호출 순서대로).
    var createdDrafts: [RoomDraft] {
        state.withLock { $0.createdDrafts }
    }

    /// joinRoom에 전달된 초대 코드 (호출 순서대로).
    var joinedCodes: [String] {
        state.withLock { $0.joinedCodes }
    }

    // MARK: - RoomRepository

    func rooms() async throws -> [Room] {
        state.withLock { $0.roomsCallCount += 1 }
        return try roomsResult.get()
    }

    func createRoom(_ draft: RoomDraft) async throws -> Room {
        state.withLock { $0.createdDrafts.append(draft) }
        return try createResult.get()
    }

    func joinRoom(inviteCode: String) async throws -> Room {
        state.withLock { $0.joinedCodes.append(inviteCode) }
        return try joinResult.get()
    }
}
