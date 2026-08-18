@testable import CameraFeature
import ComposableArchitecture
import Foundation
import Testing

@MainActor
struct CameraFeatureCoachMarkTests {

    @Test("최초 진입이면 뜸을 들인 뒤 안내 1단계가 뜬다")
    func coachMarkAppearsOnFirstEntry() async {
        let clock = TestClock()
        let store = TestStore(initialState: CameraFeatureTestFixtures.state()) {
            CameraFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.shouldShowCameraCoachMarkUseCase.run = { true }
        }

        await store.send(.view(.task)) { $0.hasStartedCoachMark = true }
        await clock.advance(by: CameraCoachMark.presentationDelay)
        await store.receive(.coachMarkDelayElapsed) { $0.coachMark = .shutterCost }
    }

    @Test("이미 본 적 있으면 진입해도 안내가 뜨지 않는다")
    func coachMarkStaysHiddenAfterSeen() async {
        let clock = TestClock()
        let store = TestStore(initialState: CameraFeatureTestFixtures.state()) {
            CameraFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.shouldShowCameraCoachMarkUseCase.run = { false }
        }

        await store.send(.view(.task)) { $0.hasStartedCoachMark = true }
        // 뜸이 지나도 coachMarkDelayElapsed가 오지 않아야 한다.
        await clock.advance(by: CameraCoachMark.presentationDelay)
    }

    @Test("액션을 누르면 2단계로 넘어가고, 한 번 더 누르면 안내가 끝나며 봤다고 기록된다")
    func coachMarkAdvancesAndRecordsSeen() async {
        let seenRecorded = LockIsolated(false)
        let store = TestStore(initialState: CameraFeatureTestFixtures.state(coachMark: .shutterCost)) {
            CameraFeature()
        } withDependencies: {
            $0.markCameraCoachMarkSeenUseCase.run = { seenRecorded.setValue(true) }
        }

        await store.send(.view(.coachMarkActionTapped)) { $0.coachMark = .shutterCaution }
        #expect(!seenRecorded.value) // 중간 단계에서는 아직 기록하지 않는다

        await store.send(.view(.coachMarkActionTapped)) { $0.coachMark = nil }
        #expect(seenRecorded.value)
    }

    @Test("한 화면 안에서 진입 액션이 두 번 와도 안내는 한 번만 시작된다")
    func coachMarkStartsOnlyOncePerScreen() async {
        let clock = TestClock()
        let showCallCount = LockIsolated(0)
        let store = TestStore(initialState: CameraFeatureTestFixtures.state(hasStartedCoachMark: true)) {
            CameraFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.shouldShowCameraCoachMarkUseCase.run = {
                showCallCount.withValue { $0 += 1 }
                return true
            }
        }

        await store.send(.view(.task))
        await clock.advance(by: CameraCoachMark.presentationDelay)
        #expect(showCallCount.value == 0) // 기록을 물어보지도 않는다
    }

    @Test("안내가 떠 있으면 화면이 안내 모드로 바뀐다")
    func coachMarkDrivesPresentationFlag() {
        #expect(CameraFeatureTestFixtures.state(coachMark: .shutterCost).isCoachMarkPresented)
        #expect(!CameraFeatureTestFixtures.state().isCoachMarkPresented)
    }

    @Test("안내를 띄운 채로 시작하면 이미 시작한 것으로 본다 — 진입 시 1단계로 되돌아가지 않는다")
    func presetCoachMarkCountsAsStarted() {
        #expect(CameraFeatureTestFixtures.state(coachMark: .shutterCaution).hasStartedCoachMark)
    }
}
