import RoomDomain
import Testing

@testable import RoomData

@Suite("InMemoryRoomRepository")
struct InMemoryRoomRepositoryTests {

    private static let inviteCode = "1928121"

    /// 초대 코드가 가리키는 방. 인원 4명으로 시작해 입장 후 5명이 되는지 본다.
    private static let joinable = Room(
        id: "room-abc",
        name: "친구들과 강릉 여행",
        status: .shooting,
        memberCount: 4,
        photoCount: 12,
        shotCount: .twentyFour,
        coverImageURL: nil,
        thumbnailURLs: []
    )

    private static func makeRepository(
        rooms: [Room] = [],
        failure: RoomError? = nil
    ) -> InMemoryRoomRepository {
        InMemoryRoomRepository(
            rooms: rooms,
            inviteCodes: [inviteCode: joinable.id],
            failure: failure
        )
    }

    // MARK: - 조회

    @Test("생성 시 넣은 방들을 순서 그대로 돌려준다")
    func returnsInitialRooms() async throws {
        let rooms = [Room.previewShooting, .previewPrintWaiting, .previewPrinted]
        let repository = Self.makeRepository(rooms: rooms)

        #expect(try await repository.rooms() == rooms)
    }

    // MARK: - 생성

    @Test("만든 방은 입력값을 반영하고 서버 몫의 값은 저장소가 채운다")
    func createdRoomHasServerAssignedValues() async throws {
        let repository = Self.makeRepository()

        let created = try await repository.createRoom(
            RoomDraft(name: "제주 우정 여행", shotCount: .fortyEight)
        )

        #expect(created.name == "제주 우정 여행")
        #expect(created.shotCount == .fortyEight)
        // 만든 직후라 촬영 중이고, 만든 사람 혼자이며, 찍은 사진이 없다.
        #expect(created.status == .shooting)
        #expect(created.memberCount == 1)
        #expect(created.photoCount == 0)
        #expect(!created.id.isEmpty)
    }

    @Test("만든 방은 목록에 남는다")
    func createdRoomAppearsInList() async throws {
        let repository = Self.makeRepository()

        let created = try await repository.createRoom(
            RoomDraft(name: "제주 우정 여행", shotCount: .default)
        )

        #expect(try await repository.rooms() == [created])
    }

    @Test("여러 번 만들면 최근 방이 맨 앞에 오고 id는 서로 다르다")
    func recentRoomComesFirst() async throws {
        let repository = Self.makeRepository(rooms: [Self.joinable])

        let first = try await repository.createRoom(RoomDraft(name: "첫 번째", shotCount: .default))
        let second = try await repository.createRoom(RoomDraft(name: "두 번째", shotCount: .default))

        let rooms = try await repository.rooms()
        #expect(rooms.map(\.name) == ["두 번째", "첫 번째", "친구들과 강릉 여행"])
        #expect(first.id != second.id)
    }

    // MARK: - 입장

    @Test("입장하면 인원이 하나 늘고 목록에도 반영된다")
    func joinIncrementsMemberCount() async throws {
        let repository = Self.makeRepository(rooms: [Self.joinable])

        let joined = try await repository.joinRoom(inviteCode: Self.inviteCode)

        #expect(joined.memberCount == 5)
        // 반환값만 갱신하고 배열에 다시 넣지 않으면 여기서 4명으로 나온다.
        #expect(try await repository.rooms().first?.memberCount == 5)
    }

    @Test("등록되지 않은 코드는 .roomNotFound를 던진다")
    func unknownInviteCodeThrows() async {
        let repository = Self.makeRepository(rooms: [Self.joinable])

        await #expect(throws: RoomError.roomNotFound) {
            _ = try await repository.joinRoom(inviteCode: "0000000")
        }
    }

    // MARK: - 실패 주입

    @Test("failure를 심으면 세 메서드 모두 그 오류를 던진다")
    func injectedFailurePropagates() async {
        let repository = Self.makeRepository(rooms: [Self.joinable], failure: .network)

        await #expect(throws: RoomError.network) {
            _ = try await repository.rooms()
        }
        await #expect(throws: RoomError.network) {
            _ = try await repository.createRoom(RoomDraft(name: "찰나", shotCount: .default))
        }
        await #expect(throws: RoomError.network) {
            _ = try await repository.joinRoom(inviteCode: Self.inviteCode)
        }
    }
}
