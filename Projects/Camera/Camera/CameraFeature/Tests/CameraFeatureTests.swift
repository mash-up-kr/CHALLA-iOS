@testable import CameraFeature
import ComposableArchitecture
import CoreGraphics
import Foundation
import PhotoDomain
import RoomDomain
import Testing

// MARK: - 촬영 조작·배율

@MainActor
struct CameraFeatureControlTests {

    @Test("진입 시 플래시는 꺼져 있다")
    func flashStartsOff() {
        #expect(CameraFeatureTestFixtures.state().flashMode == .off)
    }

    @Test("플래시 버튼을 누르면 켜짐 ↔ 꺼짐이 뒤집힌다")
    func flashToggles() async {
        let store = TestStore(initialState: CameraFeatureTestFixtures.state()) {
            CameraFeature()
        }

        await store.send(.view(.flashButtonTapped)) { $0.flashMode = .on }
        await store.send(.view(.flashButtonTapped)) { $0.flashMode = .off }
    }

    @Test("카메라 전환 버튼을 누르면 전·후면이 뒤집힌다")
    func cameraPositionToggles() async {
        let store = TestStore(initialState: CameraFeatureTestFixtures.state()) {
            CameraFeature()
        }

        await store.send(.view(.cameraSwitchButtonTapped)) { $0.cameraPosition = .front }
        await store.send(.view(.cameraSwitchButtonTapped)) { $0.cameraPosition = .back }
    }

    @Test("촬영 가능하면 셔터가 선택된 방·필터를 실어 delegate로 넘긴다")
    func shutterDelegatesWhenAvailable() async {
        let clock = TestClock()
        let store = TestStore(initialState: .fixture(selectedFilterID: "필터2")) {
            CameraFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.view(.shutterButtonTapped)) { $0.capture = CameraFeature.CaptureProgress() }
        await store.receive(.delegate(.captureRequested(roomID: 1, filterID: "필터2")))

        await clock.advance(by: .seconds(1))
        await store.receive(.minimumCaptureDisplayElapsed) { $0.capture?.isMinimumDisplayElapsed = true }
    }

    @Test("셔터를 연타해도 촬영은 한 번만 나간다")
    func shutterIgnoresRepeatedTapsWhileCapturing() async {
        let clock = TestClock()
        let store = TestStore(initialState: .fixture(selectedFilterID: "필터2")) {
            CameraFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.view(.shutterButtonTapped)) { $0.capture = CameraFeature.CaptureProgress() }
        await store.receive(.delegate(.captureRequested(roomID: 1, filterID: "필터2")))

        // 촬영이 도는 동안의 추가 탭은 아무 일도 하지 않는다.
        await store.send(.view(.shutterButtonTapped))
        await store.send(.view(.shutterButtonTapped))

        await clock.advance(by: .seconds(1))
        await store.receive(.minimumCaptureDisplayElapsed) { $0.capture?.isMinimumDisplayElapsed = true }
    }

    @Test("업로드가 최소 노출 시간보다 빨리 끝나도 1초를 채운 뒤에 방 상세로 넘어간다")
    func captureWaitsForMinimumDisplay() async {
        let clock = TestClock()
        let store = TestStore(initialState: .fixture(selectedFilterID: "필터2")) {
            CameraFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.uploadPhotoUseCase.run = { _, _, _ in 5 }
        }

        await store.send(.view(.shutterButtonTapped)) { $0.capture = CameraFeature.CaptureProgress() }
        await store.receive(.delegate(.captureRequested(roomID: 1, filterID: "필터2")))

        await store.send(.captureCompleted(roomID: 1, filterID: "필터2", jpegData: Data("jpeg".utf8))) {
            $0.capture?.photoData = Data("jpeg".utf8)
        }
        // 업로드가 끝나도 아직 넘어가지 않는다 — 최소 노출 시간이 남아 있다.
        await store.receive(.uploadResponse(roomID: 1, .success(5))) {
            $0.rooms[id: 1] = ShootableRoom(id: 1, title: "방1", remainedPhotoCount: 5, totalPhotoCount: 24)
            $0.capture?.uploadedRoomID = 1
        }

        await clock.advance(by: .seconds(1))
        await store.receive(.minimumCaptureDisplayElapsed) { $0.capture?.isMinimumDisplayElapsed = true }
        await store.receive(.delegate(.captureFinished(roomID: 1)))
    }

    @Test("최소 노출 시간이 먼저 지나면 업로드가 끝나는 즉시 방 상세로 넘어간다")
    func captureFinishesWhenUploadCompletesLast() async {
        let clock = TestClock()
        let store = TestStore(initialState: .fixture(selectedFilterID: "필터2")) {
            CameraFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.uploadPhotoUseCase.run = { _, _, _ in 5 }
        }

        await store.send(.view(.shutterButtonTapped)) { $0.capture = CameraFeature.CaptureProgress() }
        await store.receive(.delegate(.captureRequested(roomID: 1, filterID: "필터2")))

        await clock.advance(by: .seconds(1))
        await store.receive(.minimumCaptureDisplayElapsed) { $0.capture?.isMinimumDisplayElapsed = true }

        await store.send(.captureCompleted(roomID: 1, filterID: "필터2", jpegData: Data("jpeg".utf8))) {
            $0.capture?.photoData = Data("jpeg".utf8)
        }
        await store.receive(.uploadResponse(roomID: 1, .success(5))) {
            $0.rooms[id: 1] = ShootableRoom(id: 1, title: "방1", remainedPhotoCount: 5, totalPhotoCount: 24)
            $0.capture?.uploadedRoomID = 1
        }
        await store.receive(.delegate(.captureFinished(roomID: 1)))
    }

    @Test("촬영이 실패하면 연출이 풀리고 셔터가 다시 열린다")
    func shutterReopensAfterCaptureFailure() async {
        let clock = TestClock()
        let store = TestStore(initialState: .fixture(selectedFilterID: "필터2")) {
            CameraFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.view(.shutterButtonTapped)) { $0.capture = CameraFeature.CaptureProgress() }
        await store.receive(.delegate(.captureRequested(roomID: 1, filterID: "필터2")))

        await store.send(.captureFailed(message: "촬영에 실패했어요.")) {
            $0.capture = nil
            $0.toastMessage = "촬영에 실패했어요."
        }
        await clock.advance(by: .seconds(3))
        await store.receive(.toastDismissed) { $0.toastMessage = nil }
    }

    @Test("촬영이 막혀 있으면 셔터가 토스트를 띄우고 3초 뒤 스스로 사라진다")
    func shutterShowsToastWhenBlocked() async {
        let clock = TestClock()
        let store = TestStore(initialState: .fixture(rooms: CameraFeatureTestFixtures.soldOutRooms)) {
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
        let store = TestStore(initialState: CameraFeatureTestFixtures.state(rooms: [])) {
            CameraFeature()
        }

        await store.send(.view(.shutterButtonTapped))
    }

    @Test("서버 필터가 하나도 없어도 무필터로 촬영이 나간다")
    func shutterUsesNoneFilterWhenListIsEmpty() async {
        let clock = TestClock()
        let store = TestStore(initialState: CameraFeatureTestFixtures.state(filters: [])) {
            CameraFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.view(.shutterButtonTapped)) { $0.capture = CameraFeature.CaptureProgress() }
        await store.receive(.delegate(.captureRequested(roomID: 1, filterID: CameraFilter.none.id)))
        await clock.advance(by: .seconds(1))
        await store.receive(.minimumCaptureDisplayElapsed) { $0.capture?.isMinimumDisplayElapsed = true }
    }

    @Test("닫기 버튼을 누르면 화면을 닫아 달라고 알린다")
    func closeButtonRequestsClose() async {
        let store = TestStore(initialState: CameraFeatureTestFixtures.state()) {
            CameraFeature()
        }

        await store.send(.view(.closeButtonTapped))
        await store.receive(.delegate(.closeRequested))
    }

    @Test("배율 버튼을 탭하면 1x → 2x → 3x → 1x로 순환한다")
    func zoomBadgeCycles() async {
        let store = TestStore(initialState: CameraFeatureTestFixtures.state()) {
            CameraFeature()
        }

        await store.send(.view(.zoomBadgeTapped)) { $0.zoom = CameraZoom(factor: 2) }
        await store.send(.view(.zoomBadgeTapped)) { $0.zoom = CameraZoom(factor: 3) }
        await store.send(.view(.zoomBadgeTapped)) { $0.zoom = CameraZoom(factor: 1) }
    }

    @Test("핀치 배율은 제스처 시작 배율에 누적되고, 끝나면 그 자리에서 이어진다")
    func pinchAccumulatesFromGestureStart() async {
        let store = TestStore(initialState: CameraFeatureTestFixtures.state()) {
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
        let store = TestStore(initialState: CameraFeatureTestFixtures.state(zoom: CameraZoom(factor: 4))) {
            CameraFeature()
        }

        await store.send(.view(.zoomMagnificationChanged(0.001))) {
            $0.zoom.magnify(by: 0.001)
        }
        #expect(store.state.zoom.factor == CameraZoom.range.lowerBound)
    }

    @Test("아무리 키워도 최대 배율 위로 올라가지 않는다")
    func zoomStopsAtUpperBound() async {
        let store = TestStore(initialState: CameraFeatureTestFixtures.state()) {
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

    @Test("남은 장수 단계는 0장이면 unavailable, 5장 이하면 low, 그 위는 normal", arguments: [
        (remaining: 0, level: CameraCardsLevel.unavailable),
        (remaining: 1, level: CameraCardsLevel.low),
        (remaining: 5, level: CameraCardsLevel.low),
        (remaining: 6, level: CameraCardsLevel.normal),
        (remaining: 48, level: CameraCardsLevel.normal)
    ])
    func cardsLevel(remaining: Int, level: CameraCardsLevel) {
        #expect(CameraCardsLevel(remaining: remaining) == level)
    }
}

// MARK: - 방·필터 로드, 선택, 업로드

@MainActor
struct CameraFeatureDataFlowTests {

    @Test("진입 시 받은 방 중 첫 방이 선택된다")
    func firstRoomIsSelectedOnEntry() {
        let state = CameraFeatureTestFixtures.state()

        #expect(state.selectedRoomID == 1)
        #expect(state.captureAvailability == .available)
    }

    @Test("들어온 경로가 방을 지정하면 그 방으로 시작한다 — 방 상세에서 들어오는 경우")
    func entryCanPickRoom() {
        let state = CameraFeatureTestFixtures.state(selectedRoomID: 2)

        #expect(state.selectedRoomID == 2)
    }

    @Test("장수가 소진된 방으로 들어오면 촬영이 막힌 채 시작한다")
    func soldOutRoomBlocksCaptureOnEntry() {
        let state = CameraFeatureTestFixtures.state(rooms: CameraFeatureTestFixtures.soldOutRooms)

        #expect(state.captureAvailability == .noCardsLeft)
    }

    @Test("필터 목록 맨 앞은 항상 무필터(None)다")
    func noneFilterLeadsTheList() {
        let state = CameraFeatureTestFixtures.state()

        #expect(state.filters.first == CameraFilter.none)
        #expect(state.filters.map(\.id) == ["None", "필터1", "필터2", "필터3"])
    }

    @Test("서버 목록에 None이 섞여 와도 맨 앞에 한 번만 놓인다")
    func serverNoneIsDeduplicated() throws {
        let serverNone = try CameraFilter(
            name: "None",
            fileURL: #require(URL(string: "https://test.invalid/none.cube"))
        )
        let state = CameraFeatureTestFixtures.state(filters: CameraFeatureTestFixtures.filters + [serverNone])

        #expect(state.filters.map(\.id) == ["None", "필터1", "필터2", "필터3"])
        #expect(state.filters[id: "None"]?.fileURL == nil)
    }

    @Test("진입하면 무필터가 선택돼 있다")
    func noneFilterIsSelectedOnEntry() {
        #expect(CameraFeatureTestFixtures.state().selectedFilterID == CameraFilter.none.id)
    }

    @Test("필터를 고르면 선택이 바뀐다")
    func filterSelection() async {
        let store = TestStore(initialState: .fixture()) {
            CameraFeature()
        }

        await store.send(.view(.filterSelected("필터3"))) { $0.selectedFilterID = "필터3" }
    }

    @Test("목록에 없는 필터 id는 무시한다")
    func unknownFilterIsIgnored() async {
        let store = TestStore(initialState: .fixture()) {
            CameraFeature()
        }

        await store.send(.view(.filterSelected("없는필터")))
    }

    @Test("업로드가 끝나면 응답의 남은 장수로 그 방을 갱신한다")
    func uploadUpdatesRemainedCount() async {
        let store = TestStore(initialState: .fixture()) {
            CameraFeature()
        } withDependencies: {
            $0.uploadPhotoUseCase.run = { _, _, _ in 5 }
        }

        await store.send(.captureCompleted(roomID: 1, filterID: "필터1", jpegData: Data("jpeg".utf8)))
        await store.receive(.uploadResponse(roomID: 1, .success(5))) {
            $0.rooms[id: 1] = ShootableRoom(id: 1, title: "방1", remainedPhotoCount: 5, totalPhotoCount: 24)
        }
    }

    @Test("업로드 후 남은 장수가 0이면 촬영이 막힌다")
    func uploadExhaustionBlocksCapture() async {
        let store = TestStore(initialState: .fixture()) {
            CameraFeature()
        } withDependencies: {
            $0.uploadPhotoUseCase.run = { _, _, _ in 0 }
        }

        await store.send(.captureCompleted(roomID: 1, filterID: "필터1", jpegData: Data("jpeg".utf8)))
        await store.receive(.uploadResponse(roomID: 1, .success(0))) {
            $0.rooms[id: 1] = ShootableRoom(id: 1, title: "방1", remainedPhotoCount: 0, totalPhotoCount: 24)
        }
        #expect(store.state.captureAvailability == .noCardsLeft)
    }

    @Test("업로드에 실패하면 토스트를 띄우고 3초 뒤 스스로 사라진다")
    func uploadFailureShowsToast() async {
        let clock = TestClock()
        let store = TestStore(initialState: .fixture()) {
            CameraFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.uploadPhotoUseCase.run = { _, _, _ in throw PhotoError.network }
        }

        await store.send(.captureCompleted(roomID: 1, filterID: "필터1", jpegData: Data("jpeg".utf8)))
        await store.receive(.uploadResponse(roomID: 1, .failure(.network))) {
            $0.toastMessage = PhotoError.network.userMessage
        }
        await clock.advance(by: .seconds(3))
        await store.receive(.toastDismissed) { $0.toastMessage = nil }
    }
}

// MARK: - Fixtures

enum CameraFeatureTestFixtures {

    static let rooms: [ShootableRoom] = [
        ShootableRoom(id: 1, title: "방1", remainedPhotoCount: 6, totalPhotoCount: 24),
        ShootableRoom(id: 2, title: "방2", remainedPhotoCount: 3, totalPhotoCount: 48)
    ]

    /// 선택된 방이 소진된 상태를 만들 때 쓴다 — 촬영 가능 여부는 방에서 나온다.
    static let soldOutRooms: [ShootableRoom] = [
        ShootableRoom(id: 1, title: "소진된 방", remainedPhotoCount: 0, totalPhotoCount: 24)
    ]

    static let filters: [CameraFilter] = ["필터1", "필터2", "필터3"].compactMap { name in
        URL(string: "https://test.invalid/\(name).cube")
            .map { CameraFilter(name: name, fileURL: $0) }
    }

    /// 2×2×2 최소 크기의 정상 .cube 텍스트 (8행 × RGB).
    static let validCubeText = "LUT_3D_SIZE 2\n" + String(repeating: "0 0 0\n", count: 8)

    /// 진입 전에 방·필터를 이미 받아 둔 상태 — 실제 진입 경로와 같은 모양이다.
    static func state(
        rooms: [ShootableRoom] = rooms,
        filters: [CameraFilter] = filters,
        selectedRoomID: ShootableRoom.ID? = nil,
        selectedFilterID: CameraFilter.ID? = nil,
        zoom: CameraZoom = CameraZoom(),
        coachMark: CameraCoachMark? = nil,
        hasStartedCoachMark: Bool = false
    ) -> CameraFeature.State {
        CameraFeature.State(
            rooms: IdentifiedArray(uniqueElements: rooms),
            filters: IdentifiedArray(uniqueElements: filters),
            selectedRoomID: selectedRoomID,
            selectedFilterID: selectedFilterID,
            zoom: zoom,
            coachMark: coachMark,
            hasStartedCoachMark: hasStartedCoachMark
        )
    }
}

private extension CameraFeature.State {

    static func fixture(
        rooms: [ShootableRoom] = CameraFeatureTestFixtures.rooms,
        selectedFilterID: CameraFilter.ID? = nil
    ) -> Self {
        CameraFeatureTestFixtures.state(rooms: rooms, selectedFilterID: selectedFilterID)
    }
}
