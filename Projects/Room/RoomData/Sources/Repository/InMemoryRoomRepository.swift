import Foundation
import RoomDomain

/// `RoomRepository`의 임시 구현. 방을 메모리 배열에 들고 있어 앱을 끄면 사라진다.
///
/// TODO: 서버 API가 정해지면 이 파일을 지운다. 대신 `DefaultRoomRepository`를 만들어
///       HTTP 호출 → DTO 디코딩 → `Room` 변환 → 실패의 `RoomError` 매핑까지 맡긴다.
///       프로토콜이 그대로라 합성 루트의 조립 한 줄만 바뀌고 Domain·Feature는 손대지 않는다.
///
/// 주입 예시
/// ```swift
/// let repository = InMemoryRoomRepository(rooms: RoomSamples.mixed, inviteCodes: RoomSamples.inviteCodes)
/// values.fetchRoomsUseCase = .live(repository: repository)
/// values.createRoomUseCase = .live(repository: repository)
/// values.joinRoomUseCase = .live(repository: repository)
/// ```
/// `actor`인 이유 — 목록이 계속 바뀌는데 `RoomRepository`는 `Sendable`이다. 락은 `await` 구간이
/// 있어 못 쓴다(락은 스레드를 붙잡고 `await`는 놓는다). 대신 actor는 재진입을 허용하므로,
/// 기다리는 일을 `waitAndCheckFailure()`로 앞에 모으고 그 뒤로는 `await` 없이 상태를 읽고 쓴다.
///
/// 초대 코드는 `Room`에 없어(홈 카드가 쓰지 않는다) 저장소가 코드→방 매핑을 따로 들고 있다.
public actor InMemoryRoomRepository: RoomRepository {

    // 프로토콜 메서드 이름이 rooms()라 저장 프로퍼티는 이름을 달리한다.
    private var storedRooms: [Room]
    private var inviteCodes: [String: Room.ID]
    private let latency: Duration
    private let failure: RoomError?

    /// - Parameters:
    ///   - rooms: 시작 시점의 방 목록.
    ///   - inviteCodes: 초대 코드 → 방 id. 여기 없는 코드로 입장하면 `.roomNotFound`가 난다.
    ///   - latency: 응답 지연. 데모앱이 로딩 화면을 재현할 때 길게 준다.
    ///   - failure: 심으면 모든 호출이 이 오류를 던진다. 데모앱의 실패 화면 재현용.
    public init(
        rooms: [Room] = [],
        inviteCodes: [String: Room.ID] = [:],
        latency: Duration = .zero,
        failure: RoomError? = nil
    ) {
        storedRooms = rooms
        self.inviteCodes = inviteCodes
        self.latency = latency
        self.failure = failure
    }

    // MARK: - RoomRepository

    public func rooms() async throws -> [Room] {
        try await waitAndCheckFailure()
        return storedRooms
    }

    public func createRoom(_ draft: RoomDraft) async throws -> Room {
        try await waitAndCheckFailure()

        // 서버가 채울 값들을 대신 채운다. 만든 직후라 혼자이고 찍은 사진이 없다.
        let room = Room(
            id: UUID().uuidString,
            name: draft.name,
            status: .shooting,
            memberCount: 1,
            photoCount: 0,
            shotCount: draft.shotCount,
            coverImageURL: nil,
            thumbnailURLs: []
        )
        // 홈으로 돌아왔을 때 방금 만든 방이 맨 위에 보이도록 앞에 넣는다.
        storedRooms.insert(room, at: 0)
        return room
    }

    public func joinRoom(inviteCode: String) async throws -> Room {
        try await waitAndCheckFailure()

        guard let roomID = inviteCodes[inviteCode],
              let index = storedRooms.firstIndex(where: { $0.id == roomID })
        else {
            throw RoomError.roomNotFound
        }

        let joined = storedRooms[index].withMemberCount(storedRooms[index].memberCount + 1)
        storedRooms[index] = joined
        return joined
    }

    // MARK: - 공통 처리

    /// 지연만큼 기다린 뒤 실패 여부를 본다. 이 메서드가 각 호출의 유일한 `await` 지점이다.
    private func waitAndCheckFailure() async throws {
        if latency > .zero {
            try await Task.sleep(for: latency)
        }
        if let failure {
            throw failure
        }
    }
}

// MARK: - Room 갱신

private extension Room {
    /// 인원수만 바꾼 새 값. `Room`의 필드가 `let`이라 통째로 다시 만든다.
    func withMemberCount(_ count: Int) -> Room {
        Room(
            id: id,
            name: name,
            status: status,
            memberCount: count,
            photoCount: photoCount,
            shotCount: shotCount,
            coverImageURL: coverImageURL,
            thumbnailURLs: thumbnailURLs
        )
    }
}
