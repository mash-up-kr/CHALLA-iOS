@testable import CameraFeature
import ComposableArchitecture
import CoreGraphics
import Testing

@MainActor
struct CameraFeatureTests {

    // MARK: - 촬영 조작

    @Test("플래시 버튼을 누르면 켜짐 ↔ 꺼짐이 뒤집힌다")
    func flashToggles() async {
        let store = TestStore(initialState: CameraFeature.State(flashMode: .on)) {
            CameraFeature()
        }

        await store.send(.view(.flashButtonTapped)) { $0.flashMode = .off }
        await store.send(.view(.flashButtonTapped)) { $0.flashMode = .on }
    }

    @Test("카메라 전환 버튼을 누르면 전·후면이 뒤집힌다")
    func cameraPositionToggles() async {
        let store = TestStore(initialState: CameraFeature.State()) {
            CameraFeature()
        }

        await store.send(.view(.cameraSwitchButtonTapped)) { $0.cameraPosition = .front }
        await store.send(.view(.cameraSwitchButtonTapped)) { $0.cameraPosition = .back }
    }

    @Test("촬영 가능하면 셔터가 선택된 방·필터를 실어 delegate로 넘긴다")
    func shutterDelegatesWhenAvailable() async {
        let store = TestStore(initialState: .fixture(selectedFilterID: "2")) {
            CameraFeature()
        }

        await store.send(.view(.shutterButtonTapped))
        await store.receive(.delegate(.captureRequested(roomID: "1", filterID: "2")))
    }

    @Test("촬영이 막혀 있으면 셔터가 토스트를 띄우고 3초 뒤 스스로 사라진다")
    func shutterShowsToastWhenBlocked() async {
        let clock = TestClock()
        let store = TestStore(initialState: .fixture(captureAvailability: .noCardsLeft)) {
            CameraFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.view(.shutterButtonTapped)) {
            $0.toastMessage = "앗! 장수가 없어서 촬영할 수 없어요."
        }
        await clock.advance(by: .seconds(3))
        await store.receive(.toastDismissed) { $0.toastMessage = nil }
    }

    @Test("선택된 방이 없으면 셔터를 눌러도 아무 일도 일어나지 않는다")
    func shutterDoesNothingWithoutRoom() async {
        let store = TestStore(initialState: CameraFeature.State()) {
            CameraFeature()
        }

        await store.send(.view(.shutterButtonTapped))
    }

    // MARK: - 배율

    @Test("배율 버튼을 탭하면 1x → 2x → 3x → 1x로 순환한다")
    func zoomBadgeCycles() async {
        let store = TestStore(initialState: CameraFeature.State()) {
            CameraFeature()
        }

        await store.send(.view(.zoomBadgeTapped)) { $0.zoom = CameraZoom(factor: 2) }
        await store.send(.view(.zoomBadgeTapped)) { $0.zoom = CameraZoom(factor: 3) }
        await store.send(.view(.zoomBadgeTapped)) { $0.zoom = CameraZoom(factor: 1) }
    }

    @Test("핀치 배율은 제스처 시작 배율에 누적되고, 끝나면 그 자리에서 이어진다")
    func pinchAccumulatesFromGestureStart() async {
        let store = TestStore(initialState: CameraFeature.State()) {
            CameraFeature()
        }

        await store.send(.view(.zoomMagnificationChanged(2))) {
            $0.zoom.magnify(by: 2) // 1 × 2
        }
        await store.send(.view(.zoomMagnificationEnded)) {
            $0.zoom.endMagnifying()
        }
        await store.send(.view(.zoomMagnificationChanged(2))) {
            $0.zoom.magnify(by: 2) // 2 × 2
        }
        #expect(store.state.zoom.factor == 4)
    }

    @Test("아무리 줄여도 최소 배율 아래로 내려가지 않는다")
    func zoomStopsAtLowerBound() async {
        let store = TestStore(initialState: CameraFeature.State(zoom: CameraZoom(factor: 4))) {
            CameraFeature()
        }

        await store.send(.view(.zoomMagnificationChanged(0.001))) {
            $0.zoom.magnify(by: 0.001)
        }
        #expect(store.state.zoom.factor == CameraZoom.range.lowerBound)
    }

    @Test("아무리 키워도 최대 배율 위로 올라가지 않는다")
    func zoomStopsAtUpperBound() async {
        let store = TestStore(initialState: CameraFeature.State()) {
            CameraFeature()
        }

        await store.send(.view(.zoomMagnificationChanged(100))) {
            $0.zoom.magnify(by: 100)
        }
        #expect(store.state.zoom.factor == CameraZoom.range.upperBound)
    }

    @Test("배율 문구는 정수면 소수점을 떼고, 아니면 한 자리까지 보여준다", arguments: [
        (factor: CGFloat(1), label: "1x"),
        (factor: CGFloat(2), label: "2x"),
        (factor: CGFloat(1.5), label: "1.5x"),
        (factor: CGFloat(2.44), label: "2.4x")
    ])
    func zoomLabelFormat(factor: CGFloat, label: String) {
        #expect(CameraZoom(factor: factor).label == label)
    }

    // MARK: - 필터

    @Test("필터를 고르면 선택이 바뀐다")
    func filterSelection() async {
        let store = TestStore(initialState: .fixture()) {
            CameraFeature()
        }

        await store.send(.view(.filterSelected("3"))) { $0.selectedFilterID = "3" }
    }

    @Test("목록에 없는 필터 id는 무시한다")
    func unknownFilterIsIgnored() async {
        let store = TestStore(initialState: .fixture()) {
            CameraFeature()
        }

        await store.send(.view(.filterSelected("없는필터")))
    }

    // MARK: - 방 선택

    @Test("방 버튼을 누르면 드로어가 열린다")
    func roomDrawerOpens() async {
        let store = TestStore(initialState: .fixture()) {
            CameraFeature()
        }

        await store.send(.view(.roomSelectButtonTapped)) { $0.isRoomSelectionPresented = true }
    }

    @Test("방을 고르면 선택이 바뀌고 드로어가 닫힌다")
    func roomSelectionClosesDrawer() async {
        let store = TestStore(initialState: .fixture(isRoomSelectionPresented: true)) {
            CameraFeature()
        }

        await store.send(.view(.roomSelected("2"))) {
            $0.selectedRoomID = "2"
            $0.isRoomSelectionPresented = false
        }
    }

    @Test("목록에 없는 방 id는 무시한다 — 드로어도 그대로 열려 있다")
    func unknownRoomIsIgnored() async {
        let store = TestStore(initialState: .fixture(isRoomSelectionPresented: true)) {
            CameraFeature()
        }

        await store.send(.view(.roomSelected("없는방")))
    }

    @Test("드로어를 닫으면 선택은 그대로 두고 닫히기만 한다")
    func roomDrawerDismissKeepsSelection() async {
        let store = TestStore(initialState: .fixture(isRoomSelectionPresented: true)) {
            CameraFeature()
        }

        await store.send(.view(.roomSelectionDismissed)) { $0.isRoomSelectionPresented = false }
        #expect(store.state.selectedRoomID == "1")
    }

    // MARK: - 남은 장수 단계

    @Test("남은 장수 단계는 0장이면 unavailable, 5장 이하면 low, 그 위는 normal", arguments: [
        (remaining: 0, level: CameraCardsLevel.unavailable),
        (remaining: 1, level: CameraCardsLevel.low),
        (remaining: 5, level: CameraCardsLevel.low),
        (remaining: 6, level: CameraCardsLevel.normal),
        (remaining: 48, level: CameraCardsLevel.normal)
    ])
    func cardsLevel(remaining: Int, level: CameraCardsLevel) {
        let room = CameraRoom(id: "1", name: "방", remainingCards: remaining, totalCards: 48)
        #expect(room.cardsLevel == level)
    }
}

private extension CameraFeature.State {

    static func fixture(
        selectedFilterID: CameraFilter.ID? = nil,
        captureAvailability: CameraCaptureAvailability = .available,
        isRoomSelectionPresented: Bool = false
    ) -> Self {
        CameraFeature.State(
            rooms: IdentifiedArray(uniqueElements: [
                CameraRoom(id: "1", name: "방1", remainingCards: 6, totalCards: 24),
                CameraRoom(id: "2", name: "방2", remainingCards: 3, totalCards: 48)
            ]),
            filters: IdentifiedArray(uniqueElements: [
                CameraFilter(id: "1", name: "필터1"),
                CameraFilter(id: "2", name: "필터2"),
                CameraFilter(id: "3", name: "필터3")
            ]),
            selectedFilterID: selectedFilterID,
            captureAvailability: captureAvailability,
            isRoomSelectionPresented: isRoomSelectionPresented
        )
    }
}
