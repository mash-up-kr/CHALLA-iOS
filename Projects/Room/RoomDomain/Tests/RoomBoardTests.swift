import Foundation
import RoomDomain
import Testing

@Suite("RoomBoard")
struct RoomBoardTests {

    private static func card(id: Int64, status: Room.Status, checkedAt: Date? = nil) -> RoomCard {
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
            thumbnailURLs: [],
            photoPrintCompletionCheckedAt: checkedAt
        )
    }

    @Test("빈 목록이면 두 목록 모두 비고 isEmpty다")
    func emptyCards() {
        let board = RoomBoard(cards: [])

        #expect(board.active.isEmpty)
        #expect(board.printed.isEmpty)
        #expect(board.isEmpty)
    }

    @Test("촬영 중·인화 대기는 상단에만 담긴다")
    func shootingAndWaitingStayActiveOnly() {
        let cards = [Self.card(id: 1, status: .shooting), Self.card(id: 2, status: .printWaiting)]

        let board = RoomBoard(cards: cards)

        #expect(board.active == cards)
        #expect(board.printed.isEmpty)
        #expect(!board.isEmpty)
    }

    @Test("미확인 인화 완료 방은 상단에만 나온다")
    func uncheckedPrintedStaysActiveOnly() {
        let printed = Self.card(id: 1, status: .printed)

        let board = RoomBoard(cards: [printed])

        #expect(board.active == [printed])
        #expect(board.printed.isEmpty)
    }

    @Test("서버가 확인됐다고 준 인화 완료 방은 하단으로 옮겨간다 — 양쪽에 겹치지 않는다")
    func serverCheckedPrintedMovesToPrintedList() {
        let checked = Self.card(id: 1, status: .printed, checkedAt: Date(timeIntervalSince1970: 100))
        let unchecked = Self.card(id: 2, status: .printed)

        let board = RoomBoard(cards: [checked, unchecked])

        #expect(board.active == [unchecked])
        #expect(board.printed == [checked])
    }

    @Test("세션 확인 기록도 같은 효력을 갖는다 — 서버 기록이 목록에 실려 오기 전 구간용")
    func sessionCheckedPrintedMovesToPrintedList() {
        let checked = Self.card(id: 1, status: .printed)
        let unchecked = Self.card(id: 2, status: .printed)

        let board = RoomBoard(cards: [checked, unchecked], checkedPrintedRoomIDs: [1])

        #expect(board.active == [unchecked])
        #expect(board.printed == [checked])
    }

    @Test("확인 기록이 인화 완료가 아닌 방을 가리켜도 그 방은 상단에 남는다")
    func checkedIDOnNonPrintedRoomHasNoEffect() {
        let shooting = Self.card(id: 1, status: .shooting)

        let board = RoomBoard(cards: [shooting], checkedPrintedRoomIDs: [1])

        #expect(board.active == [shooting])
    }

    @Test("두 목록 모두 입력 배열(서버 정렬) 순서를 유지한다")
    func preservesInputOrder() {
        let cards = [
            Self.card(id: 1, status: .printed),
            Self.card(id: 2, status: .shooting),
            Self.card(id: 3, status: .printWaiting),
            Self.card(id: 4, status: .printed)
        ]

        let board = RoomBoard(cards: cards, checkedPrintedRoomIDs: [1, 4])

        #expect(board.active.map(\.id) == [2, 3])
        #expect(board.printed.map(\.id) == [1, 4])
    }
}
