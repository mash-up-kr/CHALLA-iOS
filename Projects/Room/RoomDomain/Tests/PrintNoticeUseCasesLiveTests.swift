@testable import RoomDomain
import Foundation
import Testing

@Suite("PrintNotice UseCases (live)")
struct PrintNoticeUseCasesLiveTests {

    /// 어느 방을 물었는지까지 남기는 가짜 저장소.
    private actor MockPrintNoticeRepository: PrintNoticeRepository {

        private(set) var askedRoomIDs: [Room.ID] = []
        private(set) var markedRoomIDs: [Room.ID] = []
        private var seen: Set<Room.ID>

        init(seen: Set<Room.ID> = []) {
            self.seen = seen
        }

        func hasSeenPrintNotice(roomID: Room.ID) async -> Bool {
            askedRoomIDs.append(roomID)
            return seen.contains(roomID)
        }

        func markPrintNoticeSeen(roomID: Room.ID) async {
            markedRoomIDs.append(roomID)
            seen.insert(roomID)
        }
    }

    @Test("본 적 없는 방이면 안내를 띄우라고 답한다")
    func showsForUnseenRoom() async {
        let repository = MockPrintNoticeRepository()
        let useCase = ShouldShowPrintNoticeUseCase.live(repository: repository)

        #expect(await useCase.run(1))
        #expect(await repository.askedRoomIDs == [1])
    }

    @Test("이미 본 방이면 띄우지 말라고 답한다 — 저장소 답을 뒤집어 전달한다")
    func hidesForSeenRoom() async {
        let repository = MockPrintNoticeRepository(seen: [1])
        let useCase = ShouldShowPrintNoticeUseCase.live(repository: repository)

        #expect(await !useCase.run(1))
    }

    @Test("기록은 물어본 방에만 남는다")
    func marksRequestedRoomOnly() async {
        let repository = MockPrintNoticeRepository()
        let mark = MarkPrintNoticeSeenUseCase.live(repository: repository)
        let shouldShow = ShouldShowPrintNoticeUseCase.live(repository: repository)

        await mark.run(1)

        #expect(await repository.markedRoomIDs == [1])
        #expect(await !shouldShow.run(1))
        #expect(await shouldShow.run(2))
    }
}
