@testable import HomeFeature
import ComposableArchitecture
import PhotoDomain
import PhotoLibrary
import RoomDomain
import Testing

/// 촬영 뱃지를 눌렀을 때의 준비 흐름 — 목록 조회와 카메라 권한이 모두 갖춰져야 카메라로 넘어간다.
@MainActor
@Suite("HomeFeature 촬영 진입")
struct HomeShootEntryTests {

    private nonisolated static let card = RoomCard.previewShooting

    private nonisolated static let shootableRooms = [
        ShootableRoom(id: card.id, title: "촬영 중인 방", remainedPhotoCount: 6, totalPhotoCount: 24)
    ]

    private nonisolated static let filters = [CameraFilter.previewFilters[0]]

    private static func makeStore(
        isPermitted: Bool = true,
        photoAuthorization: PhotoLibraryAuthorization = .authorized,
        rooms: @escaping @Sendable () async throws -> [ShootableRoom] = { shootableRooms },
        filters: @escaping @Sendable () async throws -> [CameraFilter] = { filters }
    ) -> TestStoreOf<HomeFeature> {
        var state = HomeFeature.State(nickname: "찰나")
        state.cards = [card]

        return TestStore(initialState: state) {
            HomeFeature()
        } withDependencies: {
            $0.fetchShootableRoomsUseCase.run = rooms
            $0.fetchCameraFiltersUseCase.run = filters
            $0.requestCameraPermissionUseCase.run = { isPermitted }
            $0.photoLibraryPermission.request = { _ in photoAuthorization }
        }
    }

    @Test("목록과 권한이 모두 갖춰지면 카메라 진입을 요청한다")
    func requestsCameraWhenReady() async {
        let store = Self.makeStore()

        await store.send(.view(.shootButtonTapped(Self.card.id))) {
            $0.preparingShootRoomID = Self.card.id
        }

        await store.receive(\.shootPreparationResponse.success) {
            $0.preparingShootRoomID = nil
        }
        // delegate는 App에 알리기만 하고 State를 바꾸지 않는다.
        await store.receive(\.delegate.cameraRequested)
    }

    @Test("카메라 권한을 거절하면 카메라로 넘어가지 않고 설정 안내 얼럿을 띄운다")
    func blocksWhenPermissionDenied() async {
        let store = Self.makeStore(isPermitted: false)

        await store.send(.view(.shootButtonTapped(Self.card.id))) {
            $0.preparingShootRoomID = Self.card.id
        }
        await store.receive(\.shootPreparationResponse.failure) {
            $0.preparingShootRoomID = nil
            $0.destination = .alert(ShootPreparationError.cameraPermissionDenied.alert)
        }
    }

    @Test("사진첩 권한을 거절하면 카메라로 넘어가지 않고 설정 안내 얼럿을 띄운다")
    func blocksWhenPhotoLibraryPermissionDenied() async {
        let store = Self.makeStore(photoAuthorization: .denied)

        await store.send(.view(.shootButtonTapped(Self.card.id))) {
            $0.preparingShootRoomID = Self.card.id
        }
        await store.receive(\.shootPreparationResponse.failure) {
            $0.preparingShootRoomID = nil
            $0.destination = .alert(ShootPreparationError.photoLibraryPermissionDenied.alert)
        }
    }

    @Test("사진첩이 제한 허용이어도 저장은 되므로 카메라로 넘어간다")
    func allowsLimitedPhotoLibrary() async {
        let store = Self.makeStore(photoAuthorization: .limited)

        await store.send(.view(.shootButtonTapped(Self.card.id))) {
            $0.preparingShootRoomID = Self.card.id
        }
        await store.receive(\.shootPreparationResponse.success) {
            $0.preparingShootRoomID = nil
        }
        await store.receive(\.delegate.cameraRequested)
    }

    @Test("카메라 권한을 거절하면 사진첩은 묻지 않는다 — 팝업이 겹치지 않게 순서대로 묻는다")
    func skipsPhotoLibraryWhenCameraDenied() async {
        let didAskPhotoLibrary = LockIsolated(false)
        let store = Self.makeStore(isPermitted: false)
        store.dependencies.photoLibraryPermission.request = { _ in
            didAskPhotoLibrary.setValue(true)
            return .authorized
        }

        await store.send(.view(.shootButtonTapped(Self.card.id))) {
            $0.preparingShootRoomID = Self.card.id
        }
        await store.receive(\.shootPreparationResponse.failure) {
            $0.preparingShootRoomID = nil
            $0.destination = .alert(ShootPreparationError.cameraPermissionDenied.alert)
        }
        #expect(didAskPhotoLibrary.value == false)
    }

    @Test("목록 조회에 실패하면 카메라로 넘어가지 않고 실패를 알린다")
    func blocksWhenLoadFails() async {
        let store = Self.makeStore(rooms: { throw RoomError.network })

        await store.send(.view(.shootButtonTapped(Self.card.id))) {
            $0.preparingShootRoomID = Self.card.id
        }

        let failure = ShootPreparationError.loadFailed(message: RoomError.network.userMessage)
        await store.receive(\.shootPreparationResponse.failure) {
            $0.preparingShootRoomID = nil
            $0.destination = .alert(failure.alert)
        }
    }

    @Test("권한도 없고 조회도 실패하면 권한 안내를 먼저 보여준다 — 사용자가 먼저 할 일이라서")
    func permissionTakesPrecedence() async {
        let store = Self.makeStore(isPermitted: false, rooms: { throw RoomError.network })

        await store.send(.view(.shootButtonTapped(Self.card.id))) {
            $0.preparingShootRoomID = Self.card.id
        }
        await store.receive(\.shootPreparationResponse.failure) {
            $0.preparingShootRoomID = nil
            $0.destination = .alert(ShootPreparationError.cameraPermissionDenied.alert)
        }
    }

    @Test("목록에 없는 방 id는 무시한다")
    func unknownRoomIsIgnored() async {
        let store = Self.makeStore()

        await store.send(.view(.shootButtonTapped(-999)))
    }
}
