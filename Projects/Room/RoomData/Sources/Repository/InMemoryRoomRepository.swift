import Foundation
import RoomDomain

/// `RoomRepository`의 메모리 구현. 카드를 배열에 들고 있어 앱을 끄면 사라진다.
///
/// 실서버 구현(`DefaultRoomRepository`)이 생겨도 지우지 않는다 — 데모앱이
/// 네트워크 없이 화면을 단독 실행하는 수단이다.
///
/// 주입 예시
/// ```swift
/// let repository = InMemoryRoomRepository(cards: RoomSamples.mixed, inviteCodes: RoomSamples.inviteCodes)
/// values.fetchRoomsUseCase = .live(repository: repository)
/// values.createRoomUseCase = .live(repository: repository)
/// values.joinRoomUseCase = .live(repository: repository)
/// ```
/// `actor`인 이유 — 목록이 계속 바뀌는데 `RoomRepository`는 `Sendable`이다. 락은 `await` 구간이
/// 있어 못 쓴다(락은 스레드를 붙잡고 `await`는 놓는다). 대신 actor는 재진입을 허용하므로,
/// 기다리는 일을 `waitAndCheckFailure()`로 앞에 모으고 그 뒤로는 `await` 없이 상태를 읽고 쓴다.
///
/// 초대 코드는 `RoomCard`에 없어(홈 카드가 쓰지 않는다) 저장소가 코드→방 매핑을 따로 들고 있다.
public actor InMemoryRoomRepository: RoomRepository {

    private var storedCards: [RoomCard]
    private var inviteCodes: [String: Room.ID]
    private let latency: Duration
    private let failure: RoomError?

    /// 서버 대신 지어내는 방 id. 만들 때마다 1씩 감소한다.
    /// 음수인 이유 — 서버는 항상 양수 id를 주므로, 음수만 보고도 서버가 발급하지 않은
    /// 데이터임을 알 수 있다. 프리뷰(-1…-3)·샘플(-10번대)과 겹치지 않게 -1000부터 시작한다.
    private var nextID: Int64 = -1000

    /// - Parameters:
    ///   - cards: 시작 시점의 방 목록.
    ///   - inviteCodes: 초대 코드 → 방 id. 여기 없는 코드로 입장하면 `.roomNotFound`가 난다.
    ///   - latency: 응답 지연. 데모앱이 로딩 화면을 재현할 때 길게 준다.
    ///   - failure: 심으면 모든 호출이 이 오류를 던진다. 데모앱의 실패 화면 재현용.
    public init(
        cards: [RoomCard] = [],
        inviteCodes: [String: Room.ID] = [:],
        latency: Duration = .zero,
        failure: RoomError? = nil
    ) {
        storedCards = cards
        self.inviteCodes = inviteCodes
        self.latency = latency
        self.failure = failure
    }

    // MARK: - RoomRepository

    public func rooms() async throws -> [RoomCard] {
        try await waitAndCheckFailure()
        return storedCards
    }

    public func createRoom(_ draft: RoomDraft) async throws -> RoomCard {
        try await waitAndCheckFailure()

        let id = nextID
        nextID -= 1
        let now = Date.now

        // 서버가 채울 값들을 대신 채운다. 만든 직후라 혼자이고 찍은 사진이 없다.
        let card = RoomCard(
            room: Room(
                id: id,
                title: draft.name,
                status: .shooting,
                totalPhotoCount: draft.shotCount.rawValue,
                remainedPhotoCount: draft.shotCount.rawValue,
                createdAt: now,
                expiresAt: now.addingTimeInterval(Room.previewLifetime) // 실서버 정책과 같은 30일 뒤 만료
            ),
            memberCount: 1,
            thumbnailURLs: []
        )
        // 홈으로 돌아왔을 때 방금 만든 방이 맨 위에 보이도록 앞에 넣는다.
        storedCards.insert(card, at: 0)
        return card
    }

    public func joinRoom(inviteCode: String) async throws -> RoomCard {
        try await waitAndCheckFailure()

        guard let roomID = inviteCodes[inviteCode],
              let index = storedCards.firstIndex(where: { $0.id == roomID })
        else {
            throw RoomError.roomNotFound
        }

        let joined = storedCards[index].withMemberCount(storedCards[index].memberCount + 1)
        storedCards[index] = joined
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

// MARK: - RoomCard 갱신

private extension RoomCard {
    /// 인원수만 바꾼 새 값. 필드가 `let`이라 통째로 다시 만든다.
    func withMemberCount(_ count: Int) -> RoomCard {
        RoomCard(room: room, memberCount: count, thumbnailURLs: thumbnailURLs)
    }
}
