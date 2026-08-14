import Foundation
import RoomDomain
import Testing

@Suite("RoomBoard")
struct RoomBoardTests {

    private static func card(id: Int64, status: Room.Status) -> RoomCard {
        RoomCard(
            room: Room(
                id: id,
                title: "방-\(id)",
                status: status,
                totalPhotoCount: 24,
                remainedPhotoCount: 24,
                createdAt: Date(timeIntervalSince1970: 0),
                expiresAt: Date(timeIntervalSince1970: 60 * 60 * 24 * 30)
            ),
            memberCount: 1,
            thumbnailURLs: []
        )
    }

    @Test("빈 목록이면 두 섹션 모두 비고 isEmpty다")
    func emptyCards() {
        let board = RoomBoard(cards: [])

        #expect(board.shooting.isEmpty)
        #expect(board.completed.isEmpty)
        #expect(board.isEmpty)
    }

    @Test("촬영 중만 있으면 shooting 섹션에만 담긴다")
    func shootingOnly() {
        let cards = [Self.card(id: 1, status: .shooting), Self.card(id: 2, status: .shooting)]

        let board = RoomBoard(cards: cards)

        #expect(board.shooting == cards)
        #expect(board.completed.isEmpty)
        #expect(!board.isEmpty)
    }

    @Test("인화 대기와 인화 완료는 completed 한 섹션에 함께 담긴다")
    func printWaitingAndPrintedShareCompletedSection() {
        let waiting = Self.card(id: 1, status: .printWaiting)
        let printed = Self.card(id: 2, status: .printed)

        let board = RoomBoard(cards: [waiting, printed])

        #expect(board.shooting.isEmpty)
        #expect(board.completed == [waiting, printed])
    }

    @Test("두 상태가 섞이면 두 섹션으로 갈린다")
    func mixedCards() {
        let shooting = Self.card(id: 1, status: .shooting)
        let printed = Self.card(id: 2, status: .printed)

        let board = RoomBoard(cards: [printed, shooting])

        #expect(board.shooting == [shooting])
        #expect(board.completed == [printed])
        #expect(!board.isEmpty)
    }

    @Test("섹션 안의 순서는 입력 배열의 순서를 유지한다")
    func preservesInputOrder() {
        let cards = [
            Self.card(id: 1, status: .shooting),
            Self.card(id: 2, status: .printWaiting),
            Self.card(id: 3, status: .shooting),
            Self.card(id: 4, status: .printed)
        ]

        let board = RoomBoard(cards: cards)

        #expect(board.shooting.map(\.id) == [1, 3])
        #expect(board.completed.map(\.id) == [2, 4])
    }
}
