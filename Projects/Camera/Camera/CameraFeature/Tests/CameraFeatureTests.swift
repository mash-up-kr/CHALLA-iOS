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
        let store = TestStore(initialState: .fixture(selectedFilterID: "필터2")) {
            CameraFeature()
        }

        await store.send(.view(.shutterButtonTapped))
        await store.receive(.delegate(.captureRequested(roomID: 1, filterID: "필터2")))
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

    @Test("방 목록이 오면 첫 방이 선택된다")
    func roomsLoadSelectsFirstRoom() async {
        let store = TestStore(initialState: CameraFeature.State()) {
            CameraFeature()
        }

        await store.send(.roomsResponse(.success(CameraFeatureTestFixtures.rooms))) {
            $0.rooms = IdentifiedArray(uniqueElements: CameraFeatureTestFixtures.rooms)
            $0.selectedRoomID = 1
        }
    }

    @Test("장수가 소진된 방만 오면 촬영이 막힌다")
    func soldOutRoomBlocksCapture() async {
        let soldOut = ShootableRoom(id: 3, title: "소진된 방", remainedPhotoCount: 0, totalPhotoCount: 48)
        let store = TestStore(initialState: CameraFeature.State()) {
            CameraFeature()
        }

        await store.send(.roomsResponse(.success([soldOut]))) {
            $0.rooms = [soldOut]
            $0.selectedRoomID = 3
            $0.captureAvailability = .noCardsLeft
        }
    }

    @Test("방 목록 로드에 실패하면 토스트를 띄운다")
    func roomsLoadFailureShowsToast() async {
        let clock = TestClock()
        let store = TestStore(initialState: CameraFeature.State()) {
            CameraFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.roomsResponse(.failure(.network))) {
            $0.toastMessage = RoomError.network.userMessage
        }
        await clock.advance(by: .seconds(3))
        await store.receive(.toastDismissed) { $0.toastMessage = nil }
    }

    @Test("필터 목록이 오면 첫 필터가 선택되고, LUT 등록이 끝나면 준비 완료로 표시된다")
    func filtersLoadAndPrepareLUT() async throws {
        let filter = try CameraFeatureTestFixtures.filter(name: "필터1")
        let store = TestStore(initialState: CameraFeature.State()) {
            CameraFeature()
        } withDependencies: {
            $0.loadFilterLUTUseCase.run = { _ in Data(CameraFeatureTestFixtures.validCubeText.utf8) }
        }

        await store.send(.filtersResponse(.success([filter]))) {
            $0.filters = [filter]
            $0.selectedFilterID = filter.id
        }
        await store.receive(.filterLUTPrepared(filter.id)) {
            $0.preparedFilterIDs = [filter.id]
        }
    }

    @Test("LUT 파일이 깨져 있으면 그 필터만 준비 없이 남는다 — 목록·선택은 그대로다")
    func brokenLUTLeavesFilterUnprepared() async throws {
        let filter = try CameraFeatureTestFixtures.filter(name: "깨진필터")
        let store = TestStore(initialState: CameraFeature.State()) {
            CameraFeature()
        } withDependencies: {
            $0.loadFilterLUTUseCase.run = { _ in Data("깨진 파일".utf8) }
        }

        await store.send(.filtersResponse(.success([filter]))) {
            $0.filters = [filter]
            $0.selectedFilterID = filter.id
        }
        // filterLUTPrepared가 오지 않아야 한다 — TestStore가 남은 액션 없이 끝나는 것으로 검증된다.
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

        await store.send(.view(.roomSelected(2))) {
            $0.selectedRoomID = 2
            $0.isRoomSelectionPresented = false
        }
    }

    @Test("장수가 소진된 방을 고르면 촬영이 막히고, 남은 방을 고르면 다시 풀린다")
    func roomSelectionRecomputesAvailability() async {
        let soldOut = ShootableRoom(id: 3, title: "소진된 방", remainedPhotoCount: 0, totalPhotoCount: 48)
        let store = TestStore(
            initialState: .fixture(rooms: CameraFeatureTestFixtures.rooms + [soldOut], isRoomSelectionPresented: true)
        ) {
            CameraFeature()
        }

        await store.send(.view(.roomSelected(3))) {
            $0.selectedRoomID = 3
            $0.isRoomSelectionPresented = false
            $0.captureAvailability = .noCardsLeft
        }
        await store.send(.view(.roomSelectButtonTapped)) { $0.isRoomSelectionPresented = true }
        await store.send(.view(.roomSelected(1))) {
            $0.selectedRoomID = 1
            $0.isRoomSelectionPresented = false
            $0.captureAvailability = .available
        }
    }

    @Test("목록에 없는 방 id는 무시한다 — 드로어도 그대로 열려 있다")
    func unknownRoomIsIgnored() async {
        let store = TestStore(initialState: .fixture(isRoomSelectionPresented: true)) {
            CameraFeature()
        }

        await store.send(.view(.roomSelected(999)))
    }

    @Test("드로어를 닫으면 선택은 그대로 두고 닫히기만 한다")
    func roomDrawerDismissKeepsSelection() async {
        let store = TestStore(initialState: .fixture(isRoomSelectionPresented: true)) {
            CameraFeature()
        }

        await store.send(.view(.roomSelectionDismissed)) { $0.isRoomSelectionPresented = false }
        #expect(store.state.selectedRoomID == 1)
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
            $0.captureAvailability = .noCardsLeft
        }
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

    static func filter(name: String) throws -> CameraFilter {
        let fileURL = try #require(URL(string: "https://test.invalid/\(name).cube"))
        return CameraFilter(name: name, fileURL: fileURL)
    }

    /// 2×2×2 최소 크기의 정상 .cube 텍스트 (8행 × RGB).
    static let validCubeText = "LUT_3D_SIZE 2\n" + String(repeating: "0 0 0\n", count: 8)
}

private extension CameraFeature.State {

    static func fixture(
        rooms: [ShootableRoom] = CameraFeatureTestFixtures.rooms,
        selectedFilterID: CameraFilter.ID? = nil,
        captureAvailability: CameraCaptureAvailability = .available,
        isRoomSelectionPresented: Bool = false
    ) -> Self {
        CameraFeature.State(
            rooms: IdentifiedArray(uniqueElements: rooms),
            filters: IdentifiedArray(
                uniqueElements: ["필터1", "필터2", "필터3"].compactMap { name in
                    URL(string: "https://test.invalid/\(name).cube")
                        .map { CameraFilter(name: name, fileURL: $0) }
                }
            ),
            selectedFilterID: selectedFilterID,
            captureAvailability: captureAvailability,
            isRoomSelectionPresented: isRoomSelectionPresented
        )
    }
}
