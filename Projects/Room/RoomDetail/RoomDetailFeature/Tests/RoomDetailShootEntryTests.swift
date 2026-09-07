@testable import RoomDetailFeature
import ComposableArchitecture
import PhotoDomain
import PhotoLibrary
import RoomDomain
import ShootEntry
import Testing

/// 사진 찍기 버튼을 눌렀을 때 방 상세가 하는 일 — 준비 중 표시, 성공하면 delegate, 실패하면 얼럿.
/// 준비 자체(권한 순서·조회 실패 판단)는 `ShootEntry`의 테스트가 본다.
@MainActor
@Suite("RoomDetailFeature 촬영 진입")
struct RoomDetailShootEntryTests {

    private nonisolated static let room = Room.previewShooting

    private nonisolated static let shootableRooms = [
        ShootableRoom(id: room.id, title: room.title, remainedPhotoCount: 6, totalPhotoCount: 24)
    ]

    private nonisolated static let filters = [CameraFilter.previewFilters[0]]

    private static func makeStore(
        isPermitted: Bool = true,
        rooms: @escaping @Sendable () async throws -> [ShootableRoom] = { shootableRooms }
    ) -> TestStoreOf<RoomDetailFeature> {
        TestStore(initialState: RoomDetailFeature.State(room: room)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchShootableRoomsUseCase.run = rooms
            $0.fetchCameraFiltersUseCase.run = { filters }
            $0.prepareCameraFiltersUseCase.run = { _ in }
            $0.requestCameraPermissionUseCase.run = { isPermitted }
            $0.photoLibraryPermission.request = { _ in .authorized }
        }
    }

    @Test("준비가 끝나면 이 방이 선택된 카메라 진입을 요청한다")
    func requestsCameraWhenReady() async {
        let store = Self.makeStore()

        await store.send(.view(.shootButtonTapped)) {
            $0.isPreparingShoot = true
        }

        await store.receive(\.shootPreparationResponse.success) {
            $0.isPreparingShoot = false
        }
        // 이 방이 선택된 채로 열리도록 방 id가 함께 나간다.
        await store.receive(
            \.delegate.cameraRequested,
            CameraEntry(roomID: Self.room.id, rooms: Self.shootableRooms, filters: Self.filters)
        )
    }

    @Test("준비 중에는 다시 눌러도 준비를 새로 시작하지 않는다")
    func ignoresRepeatedTapWhilePreparing() async {
        // 첫 준비를 붙잡아 둔 채로 다시 눌러 본다 — 목록 조회가 두 번 나가면 안 된다.
        let gate = AsyncStream<Void>.makeStream()
        let requestCount = LockIsolated(0)
        let store = Self.makeStore(rooms: {
            requestCount.withValue { $0 += 1 }
            for await _ in gate.stream {}
            return Self.shootableRooms
        })

        await store.send(.view(.shootButtonTapped)) {
            $0.isPreparingShoot = true
        }
        await store.send(.view(.shootButtonTapped))
        gate.continuation.finish()

        await store.receive(\.shootPreparationResponse.success) {
            $0.isPreparingShoot = false
        }
        await store.receive(\.delegate.cameraRequested)

        #expect(requestCount.value == 1)
    }

    @Test("권한을 거절하면 카메라로 넘어가지 않고 설정 안내 얼럿을 띄운다")
    func blocksWhenPermissionDenied() async {
        let store = Self.makeStore(isPermitted: false)

        await store.send(.view(.shootButtonTapped)) {
            $0.isPreparingShoot = true
        }
        await store.receive(\.shootPreparationResponse.failure) {
            $0.isPreparingShoot = false
            $0.alert = ShootPreparationError.cameraPermissionDenied
                .alert(openSettings: .openSettingsTapped)
        }
    }

    @Test("목록 조회에 실패하면 카메라로 넘어가지 않고 실패 문구를 그대로 알린다")
    func blocksWhenLoadFails() async {
        let store = Self.makeStore(rooms: { throw RoomError.network })

        await store.send(.view(.shootButtonTapped)) {
            $0.isPreparingShoot = true
        }

        let failure = ShootPreparationError.loadFailed(message: RoomError.network.userMessage)
        await store.receive(\.shootPreparationResponse.failure) {
            $0.isPreparingShoot = false
            $0.alert = failure.alert(openSettings: .openSettingsTapped)
        }
    }

    @Test("얼럿의 설정 열기를 누르면 앱 설정 화면을 연다")
    func opensSettingsFromAlert() async {
        let didOpen = LockIsolated(false)
        let store = Self.makeStore(isPermitted: false)
        store.dependencies.openCameraSettingsUseCase.run = { didOpen.setValue(true) }

        await store.send(.view(.shootButtonTapped)) {
            $0.isPreparingShoot = true
        }
        await store.receive(\.shootPreparationResponse.failure) {
            $0.isPreparingShoot = false
            $0.alert = ShootPreparationError.cameraPermissionDenied
                .alert(openSettings: .openSettingsTapped)
        }

        // 얼럿 버튼을 누르면 얼럿은 함께 내려간다.
        await store.send(.alert(.presented(.openSettingsTapped))) {
            $0.alert = nil
        }
        await store.finish()

        #expect(didOpen.value)
    }
}
