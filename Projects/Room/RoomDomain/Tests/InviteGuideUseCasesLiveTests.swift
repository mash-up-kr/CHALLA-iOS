@testable import RoomDomain
import os
import Testing

/// 초대 안내 UseCase 2종의 live 조립 — 기록이 없을 때만 띄우라고 답하는지,
/// 기록이 이후 조회에 반영되는지 검증한다.
@Suite("초대 안내 UseCase.live")
struct InviteGuideUseCasesLiveTests {

    /// 안내 노출 기록을 메모리에 들고 있는 목 (PhotoDomain의 MockCameraOnboardingRepository와 같은 구조).
    private final class MockInviteGuideRepository: InviteGuideRepository {

        private let state: OSAllocatedUnfairLock<Bool>

        init(hasSeen: Bool = false) {
            state = OSAllocatedUnfairLock(initialState: hasSeen)
        }

        var didMarkSeen: Bool {
            state.withLock { $0 }
        }

        func hasSeenInviteGuide() async -> Bool {
            state.withLock { $0 }
        }

        func markInviteGuideSeen() async {
            state.withLock { $0 = true }
        }
    }

    @Test("본 적 없으면 안내를 띄우라고 답한다")
    func showsWhenNeverSeen() async {
        let useCase = ShouldShowInviteGuideUseCase.live(
            repository: MockInviteGuideRepository(hasSeen: false)
        )

        #expect(await useCase.run())
    }

    @Test("이미 본 적 있으면 안내를 띄우지 말라고 답한다")
    func hidesWhenAlreadySeen() async {
        let useCase = ShouldShowInviteGuideUseCase.live(
            repository: MockInviteGuideRepository(hasSeen: true)
        )

        #expect(await !useCase.run())
    }

    @Test("봤다고 기록하면 이후 조회에서 띄우지 않는다")
    func markingSeenStops() async {
        let repository = MockInviteGuideRepository(hasSeen: false)
        let mark = MarkInviteGuideSeenUseCase.live(repository: repository)
        let shouldShow = ShouldShowInviteGuideUseCase.live(repository: repository)

        await mark.run()

        #expect(repository.didMarkSeen)
        #expect(await !shouldShow.run())
    }
}
