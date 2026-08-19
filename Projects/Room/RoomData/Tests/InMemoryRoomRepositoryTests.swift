@testable import RoomData
import Foundation
import RoomDomain
import Testing

@Suite("InMemoryRoomRepository")
struct InMemoryRoomRepositoryTests {

    private static let inviteCode = "1928121"

    /// 초대 코드가 가리키는 방. 인원 4명으로 시작해 입장 후 5명이 되는지 본다.
    private static let joinable = RoomCard(
        room: Room(
            id: -50,
            title: "친구들과 강릉 여행",
            status: .shooting,
            totalPhotoCount: 24,
            remainedPhotoCount: 12,
            createdAt: Date(timeIntervalSince1970: 0),
            expiresAt: Date(timeIntervalSince1970: 60 * 60 * 24 * 30)
        ),
        memberCount: 4,
        thumbnailURLs: []
    )

    private static func makeRepository(
        cards: [RoomCard] = [],
        failure: RoomError? = nil
    ) -> InMemoryRoomRepository {
        InMemoryRoomRepository(
            cards: cards,
            inviteCodes: [inviteCode: joinable.id],
            failure: failure
        )
    }

    // MARK: - 조회

    @Test("생성 시 넣은 방들을 순서 그대로 돌려준다")
    func returnsInitialCards() async throws {
        let cards = [RoomCard.previewShooting, .previewPrintWaiting, .previewPrinted]
        let repository = Self.makeRepository(cards: cards)

        #expect(try await repository.rooms() == cards)
    }

    // MARK: - 생성

    @Test("만든 방은 입력값을 반영하고 서버 몫의 값은 저장소가 채운다")
    func createdRoomHasServerAssignedValues() async throws {
        let repository = Self.makeRepository()

        let created = try await repository.createRoom(
            RoomDraft(name: "제주 우정 여행", shotCount: .fortyEight)
        )

        #expect(created.room.title == "제주 우정 여행")
        #expect(created.room.totalPhotoCount == 48)
        // 만든 직후라 촬영 중이고, 만든 사람 혼자이며, 찍은 사진이 없다.
        #expect(created.room.status == .shooting)
        #expect(created.memberCount == 1)
        #expect(created.room.shotPhotoCount == 0)
        // 서버가 발급하지 않은 id는 음수라는 표식을 지킨다.
        #expect(created.id < 0)
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
        let repository = Self.makeRepository(cards: [Self.joinable])

        let first = try await repository.createRoom(RoomDraft(name: "첫 번째", shotCount: .default))
        let second = try await repository.createRoom(RoomDraft(name: "두 번째", shotCount: .default))

        let cards = try await repository.rooms()
        #expect(cards.map(\.room.title) == ["두 번째", "첫 번째", "친구들과 강릉 여행"])
        #expect(first.id != second.id)
    }

    // MARK: - 입장

    @Test("입장하면 인원이 하나 늘고 목록에도 반영된다")
    func joinIncrementsMemberCount() async throws {
        let repository = Self.makeRepository(cards: [Self.joinable])

        let joined = try await repository.joinRoom(inviteCode: Self.inviteCode)

        #expect(joined.memberCount == 5)
        // 반환값만 갱신하고 배열에 다시 넣지 않으면 여기서 4명으로 나온다.
        #expect(try await repository.rooms().first?.memberCount == 5)
    }

    @Test("등록되지 않은 코드는 .roomNotFound를 던진다")
    func unknownInviteCodeThrows() async {
        let repository = Self.makeRepository(cards: [Self.joinable])

        await #expect(throws: RoomError.roomNotFound) {
            _ = try await repository.joinRoom(inviteCode: "0000000")
        }
    }

    // MARK: - 방 상세

    @Test("등록된 방의 상세는 입장 매핑을 거꾸로 찾은 초대 코드를 준다")
    func roomInfoUsesRegisteredInviteCode() async throws {
        let repository = Self.makeRepository(cards: [Self.joinable])

        let info = try await repository.roomInfo(id: Self.joinable.id)

        #expect(info.room == Self.joinable.room)
        #expect(info.invitationCode == Self.inviteCode)
    }

    @Test("등록 안 된 방의 초대 코드는 id로 만든 일곱 자리다")
    func roomInfoFabricatesCodeForUnregisteredRoom() async throws {
        let card = RoomCard.previewShooting // id -1, 입장 매핑에 없는 방
        let repository = Self.makeRepository(cards: [card])

        let info = try await repository.roomInfo(id: card.id)

        #expect(info.invitationCode == "0000001")
    }

    @Test("참여자는 주입한 구성 그대로 온다")
    func membersReturnInjectedList() async throws {
        let members = RoomDetail.preview.members
        let repository = InMemoryRoomRepository(
            cards: [Self.joinable],
            membersByRoom: [Self.joinable.id: members]
        )

        #expect(try await repository.members(roomID: Self.joinable.id) == members)
    }

    @Test("없는 방은 상세·참여자 모두 .roomNotFound를 던진다")
    func unknownRoomThrows() async {
        let repository = Self.makeRepository(cards: [Self.joinable])

        await #expect(throws: RoomError.roomNotFound) {
            _ = try await repository.roomInfo(id: -999)
        }
        await #expect(throws: RoomError.roomNotFound) {
            _ = try await repository.members(roomID: -999)
        }
    }

    // MARK: - 실패 주입

    @Test("failure를 심으면 모든 메서드가 그 오류를 던진다")
    func injectedFailurePropagates() async {
        let repository = Self.makeRepository(cards: [Self.joinable], failure: .network)

        await #expect(throws: RoomError.network) {
            _ = try await repository.rooms()
        }
        await #expect(throws: RoomError.network) {
            _ = try await repository.createRoom(RoomDraft(name: "찰나", shotCount: .default))
        }
        await #expect(throws: RoomError.network) {
            _ = try await repository.joinRoom(inviteCode: Self.inviteCode)
        }
        await #expect(throws: RoomError.network) {
            _ = try await repository.roomInfo(id: Self.joinable.id)
        }
        await #expect(throws: RoomError.network) {
            _ = try await repository.members(roomID: Self.joinable.id)
        }
    }
}
