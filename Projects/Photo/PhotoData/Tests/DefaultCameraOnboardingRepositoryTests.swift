@testable import PhotoData
import Foundation
import Testing

@Suite("DefaultCameraOnboardingRepository")
struct DefaultCameraOnboardingRepositoryTests {

    @Test("기록이 없으면 아직 안 본 것으로 본다")
    func defaultsToUnseen() async {
        let repository = DefaultCameraOnboardingRepository(storage: InMemoryCameraOnboardingStorage())

        #expect(await !repository.hasSeenCoachMark())
    }

    @Test("봤다고 기록하면 그 뒤로는 본 것으로 답한다")
    func remembersSeen() async {
        let repository = DefaultCameraOnboardingRepository(storage: InMemoryCameraOnboardingStorage())

        await repository.markCoachMarkSeen()

        #expect(await repository.hasSeenCoachMark())
    }

    @Test("이미 기록된 저장소를 물려받으면 처음부터 본 것으로 답한다 — 앱을 다시 켠 상황")
    func readsExistingRecord() async {
        let storage = InMemoryCameraOnboardingStorage()
        await DefaultCameraOnboardingRepository(storage: storage).markCoachMarkSeen()

        // 저장소만 남기고 저장소를 쓰는 쪽을 새로 만든다.
        let relaunched = DefaultCameraOnboardingRepository(storage: storage)

        #expect(await relaunched.hasSeenCoachMark())
    }
}
