import RoomDomain
import Testing

@Suite("RoomBoard")
struct RoomBoardTests {

    private static func room(id: String, status: Room.Status) -> Room {
        Room(
            id: id,
            name: "방-\(id)",
            status: status,
            memberCount: 1,
            photoCount: 0,
            shotCount: .default,
            coverImageURL: nil,
            thumbnailURLs: []
        )
    }

    @Test("빈 목록이면 두 섹션 모두 비고 isEmpty다")
    func emptyRooms() {
        let board = RoomBoard(rooms: [])

        #expect(board.shooting.isEmpty)
        #expect(board.completed.isEmpty)
        #expect(board.isEmpty)
    }

    @Test("촬영 중만 있으면 shooting 섹션에만 담긴다")
    func shootingOnly() {
        let rooms = [Self.room(id: "a", status: .shooting), Self.room(id: "b", status: .shooting)]

        let board = RoomBoard(rooms: rooms)

        #expect(board.shooting == rooms)
        #expect(board.completed.isEmpty)
        #expect(!board.isEmpty)
    }

    @Test("인화 대기와 인화 완료는 completed 한 섹션에 함께 담긴다")
    func printWaitingAndPrintedShareCompletedSection() {
        let waiting = Self.room(id: "waiting", status: .printWaiting)
        let printed = Self.room(id: "printed", status: .printed)

        let board = RoomBoard(rooms: [waiting, printed])

        #expect(board.shooting.isEmpty)
        #expect(board.completed == [waiting, printed])
    }

    @Test("두 상태가 섞이면 두 섹션으로 갈린다")
    func mixedRooms() {
        let shooting = Self.room(id: "shooting", status: .shooting)
        let printed = Self.room(id: "printed", status: .printed)

        let board = RoomBoard(rooms: [printed, shooting])

        #expect(board.shooting == [shooting])
        #expect(board.completed == [printed])
        #expect(!board.isEmpty)
    }

    @Test("섹션 안의 순서는 입력 배열의 순서를 유지한다")
    func preservesInputOrder() {
        let rooms = [
            Self.room(id: "s1", status: .shooting),
            Self.room(id: "c1", status: .printWaiting),
            Self.room(id: "s2", status: .shooting),
            Self.room(id: "c2", status: .printed)
        ]

        let board = RoomBoard(rooms: rooms)

        #expect(board.shooting.map(\.id) == ["s1", "s2"])
        #expect(board.completed.map(\.id) == ["c1", "c2"])
    }
}
