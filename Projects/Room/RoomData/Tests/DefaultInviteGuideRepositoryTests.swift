@testable import RoomData
import Foundation
import os
import Testing

@Suite("DefaultInviteGuideRepository")
struct DefaultInviteGuideRepositoryTests {

    /// 테스트가 실제 `UserDefaults`를 건드리지 않도록 메모리에만 담아두는 저장소.
    private final class InMemoryInviteGuideStorage: InviteGuideStorage {

        private let values = OSAllocatedUnfairLock<[String: Bool]>(initialState: [:])

        func bool(forKey key: String) -> Bool {
            values.withLock { $0[key] ?? false }
        }

        func setBool(_ value: Bool, forKey key: String) {
            values.withLock { $0[key] = value }
        }
    }

    @Test("기록이 없으면 아직 안 본 것으로 본다")
    func defaultsToUnseen() async {
        let repository = DefaultInviteGuideRepository(storage: InMemoryInviteGuideStorage())

        #expect(await !repository.hasSeenInviteGuide())
    }

    @Test("봤다고 기록하면 그 뒤로는 본 것으로 답한다")
    func remembersSeen() async {
        let repository = DefaultInviteGuideRepository(storage: InMemoryInviteGuideStorage())

        await repository.markInviteGuideSeen()

        #expect(await repository.hasSeenInviteGuide())
    }

    @Test("이미 기록해 뒀다면 앱을 다시 켜도 본 것으로 답한다")
    func readsExistingRecord() async {
        let storage = InMemoryInviteGuideStorage()
        await DefaultInviteGuideRepository(storage: storage).markInviteGuideSeen()

        // 같은 저장소로 리포지토리를 새로 만든다 — 앱을 껐다 켠 상황에 해당한다.
        let relaunched = DefaultInviteGuideRepository(storage: storage)

        #expect(await relaunched.hasSeenInviteGuide())
    }
}
