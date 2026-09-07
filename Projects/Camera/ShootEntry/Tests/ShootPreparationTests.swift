@testable import ShootEntry
import ComposableArchitecture
import PhotoDomain
import PhotoLibrary
import RoomDomain
import Testing

/// 촬영 진입 준비 — 목록·LUT·권한이 모두 갖춰져야 카메라로 넘어간다.
/// 화면이 없는 순수 로직이라 시뮬레이터 없이 돈다.
@Suite("ShootPreparation 촬영 진입 준비")
struct ShootPreparationTests {

    private static let rooms = [
        ShootableRoom(id: 1, title: "촬영 중인 방", remainedPhotoCount: 6, totalPhotoCount: 24)
    ]

    private static let filters = [CameraFilter.previewFilters[0]]

    /// 준비를 한 번 돌린다. 인자로 어긋나는 조건만 바꿔 끼운다.
    private static func run(
        roomID: Room.ID = 1,
        isCameraPermitted: Bool = true,
        photoAuthorization: PhotoLibraryAuthorization = .authorized,
        fetchRooms: @escaping @Sendable () async throws -> [ShootableRoom] = { rooms },
        fetchFilters: @escaping @Sendable () async throws -> [CameraFilter] = { filters },
        prepareLUTs: @escaping @Sendable ([CameraFilter]) async throws -> Void = { _ in },
        didAskPhotoLibrary: LockIsolated<Bool> = LockIsolated(false)
    ) async throws -> Result<CameraEntry, ShootPreparationError> {
        let preparation = withDependencies {
            $0.fetchShootableRoomsUseCase.run = fetchRooms
            $0.fetchCameraFiltersUseCase.run = fetchFilters
            $0.prepareCameraFiltersUseCase.run = prepareLUTs
            $0.requestCameraPermissionUseCase.run = { isCameraPermitted }
            $0.photoLibraryPermission.request = { _ in
                didAskPhotoLibrary.setValue(true)
                return photoAuthorization
            }
        } operation: {
            ShootPreparation()
        }

        return try await preparation.run(roomID: roomID)
    }

    @Test("목록과 권한이 모두 갖춰지면 누른 방이 선택된 재료를 돌려준다")
    func succeedsWhenReady() async throws {
        let result = try await Self.run(roomID: 1)

        #expect(result == .success(CameraEntry(roomID: 1, rooms: Self.rooms, filters: Self.filters)))
    }

    @Test("카메라 권한을 거절하면 준비가 실패한다")
    func failsWhenCameraDenied() async throws {
        let result = try await Self.run(isCameraPermitted: false)

        #expect(result == .failure(.cameraPermissionDenied))
    }

    @Test("사진첩 권한을 거절하면 준비가 실패한다 — 저장 못 하면 셔터마다 실패한다")
    func failsWhenPhotoLibraryDenied() async throws {
        let result = try await Self.run(photoAuthorization: .denied)

        #expect(result == .failure(.photoLibraryPermissionDenied))
    }

    @Test("사진첩이 제한 허용이어도 저장은 되므로 통과한다")
    func allowsLimitedPhotoLibrary() async throws {
        let result = try await Self.run(photoAuthorization: .limited)

        #expect(result == .success(CameraEntry(roomID: 1, rooms: Self.rooms, filters: Self.filters)))
    }

    @Test("카메라 권한을 거절하면 사진첩은 묻지 않는다 — 팝업이 겹치지 않게 순서대로 묻는다")
    func skipsPhotoLibraryWhenCameraDenied() async throws {
        let didAsk = LockIsolated(false)

        _ = try await Self.run(isCameraPermitted: false, didAskPhotoLibrary: didAsk)

        #expect(didAsk.value == false)
    }

    @Test("목록 조회에 실패하면 그 도메인의 문구를 그대로 싣는다")
    func failsWithRoomErrorMessage() async throws {
        let result = try await Self.run(fetchRooms: { throw RoomError.network })

        #expect(result == .failure(.loadFailed(message: RoomError.network.userMessage)))
    }

    @Test("LUT를 못 받으면 준비가 실패한다 — 필터가 안 먹는 화면을 띄우지 않는다")
    func failsWhenLUTPreparationFails() async throws {
        let result = try await Self.run(prepareLUTs: { _ in throw PhotoError.network })

        #expect(result == .failure(.loadFailed(message: PhotoError.network.userMessage)))
    }

    @Test("필터 목록을 받은 뒤에 그 목록으로 LUT를 준비한다")
    func preparesLUTsForFetchedFilters() async throws {
        let prepared = LockIsolated<[CameraFilter]>([])

        _ = try await Self.run(prepareLUTs: { prepared.setValue($0) })

        #expect(prepared.value == Self.filters)
    }

    @Test("권한도 없고 조회도 실패하면 권한 거절을 먼저 알린다 — 사용자가 먼저 할 일이라서")
    func permissionTakesPrecedenceOverLoadFailure() async throws {
        let result = try await Self.run(
            isCameraPermitted: false,
            fetchRooms: { throw RoomError.network }
        )

        #expect(result == .failure(.cameraPermissionDenied))
    }
}
