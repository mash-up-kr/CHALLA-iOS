@testable import RoomData
import Foundation
import RoomDomain
import Testing

@Suite("DefaultPrintNoticeRepository")
struct DefaultPrintNoticeRepositoryTests {

    @Test("기록이 없으면 아직 안 본 것으로 본다")
    func defaultsToUnseen() async {
        let repository = DefaultPrintNoticeRepository(storage: InMemoryPrintNoticeStorage())

        #expect(await !repository.hasSeenPrintNotice(roomID: 1))
    }

    @Test("봤다고 기록하면 그 뒤로는 본 것으로 답한다")
    func remembersSeen() async {
        let repository = DefaultPrintNoticeRepository(storage: InMemoryPrintNoticeStorage())

        await repository.markPrintNoticeSeen(roomID: 1)

        #expect(await repository.hasSeenPrintNotice(roomID: 1))
    }

    @Test("기록은 방마다 따로 남는다 — 한 방에서 봤다고 다른 방의 안내가 사라지지 않는다")
    func recordsPerRoom() async {
        let repository = DefaultPrintNoticeRepository(storage: InMemoryPrintNoticeStorage())

        await repository.markPrintNoticeSeen(roomID: 1)

        #expect(await repository.hasSeenPrintNotice(roomID: 1))
        #expect(await !repository.hasSeenPrintNotice(roomID: 2))
    }

    @Test("이미 기록된 저장소를 물려받으면 처음부터 본 것으로 답한다 — 앱을 다시 켠 상황")
    func readsExistingRecord() async {
        let storage = InMemoryPrintNoticeStorage()
        await DefaultPrintNoticeRepository(storage: storage).markPrintNoticeSeen(roomID: 7)

        // 저장소만 남기고 저장소를 쓰는 쪽을 새로 만든다.
        let relaunched = DefaultPrintNoticeRepository(storage: storage)

        #expect(await relaunched.hasSeenPrintNotice(roomID: 7))
    }
}
