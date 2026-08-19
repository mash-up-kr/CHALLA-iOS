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
        var shootableRoomsCallCount = 0
        var createdDrafts: [RoomDraft] = []
        var joinedCodes: [String] = []
        var roomInfoIDs: [Room.ID] = []
        var memberRoomIDs: [Room.ID] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let roomsResult: Result<[RoomCard], RoomError>
    private let shootableRoomsResult: Result<[ShootableRoom], RoomError>
    private let createResult: Result<RoomCard, RoomError>
    private let joinResult: Result<RoomCard, RoomError>
    private let roomInfoResult: Result<(room: Room, invitationCode: String), RoomError>
    private let membersResult: Result<[RoomMember], RoomError>

    init(
        roomsResult: Result<[RoomCard], RoomError> = .failure(.unknown),
        shootableRoomsResult: Result<[ShootableRoom], RoomError> = .failure(.unknown),
        createResult: Result<RoomCard, RoomError> = .failure(.unknown),
        joinResult: Result<RoomCard, RoomError> = .failure(.unknown),
        roomInfoResult: Result<(room: Room, invitationCode: String), RoomError> = .failure(.unknown),
        membersResult: Result<[RoomMember], RoomError> = .failure(.unknown)
    ) {
        self.roomsResult = roomsResult
        self.shootableRoomsResult = shootableRoomsResult
        self.createResult = createResult
        self.joinResult = joinResult
        self.roomInfoResult = roomInfoResult
        self.membersResult = membersResult
    }

    // MARK: - 검증용 프로퍼티

    /// rooms() 호출 횟수.
    var roomsCallCount: Int {
        state.withLock { $0.roomsCallCount }
    }

    /// shootableRooms() 호출 횟수.
    var shootableRoomsCallCount: Int {
        state.withLock { $0.shootableRoomsCallCount }
    }

    /// createRoom에 전달된 draft (호출 순서대로).
    var createdDrafts: [RoomDraft] {
        state.withLock { $0.createdDrafts }
    }

    /// joinRoom에 전달된 초대 코드 (호출 순서대로).
    var joinedCodes: [String] {
        state.withLock { $0.joinedCodes }
    }

    /// roomInfo에 전달된 방 id (호출 순서대로).
    var roomInfoIDs: [Room.ID] {
        state.withLock { $0.roomInfoIDs }
    }

    /// members에 전달된 방 id (호출 순서대로).
    var memberRoomIDs: [Room.ID] {
        state.withLock { $0.memberRoomIDs }
    }

    // MARK: - RoomRepository

    func rooms() async throws -> [RoomCard] {
        state.withLock { $0.roomsCallCount += 1 }
        return try roomsResult.get()
    }

    func shootableRooms() async throws -> [ShootableRoom] {
        state.withLock { $0.shootableRoomsCallCount += 1 }
        return try shootableRoomsResult.get()
    }

    func createRoom(_ draft: RoomDraft) async throws -> RoomCard {
        state.withLock { $0.createdDrafts.append(draft) }
        return try createResult.get()
    }

    func joinRoom(inviteCode: String) async throws -> RoomCard {
        state.withLock { $0.joinedCodes.append(inviteCode) }
        return try joinResult.get()
    }

    func roomInfo(id: Room.ID) async throws -> (room: Room, invitationCode: String) {
        state.withLock { $0.roomInfoIDs.append(id) }
        return try roomInfoResult.get()
    }

    func members(roomID: Room.ID) async throws -> [RoomMember] {
        state.withLock { $0.memberRoomIDs.append(roomID) }
        return try membersResult.get()
    }
}
