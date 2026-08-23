import ComposableArchitecture
import PhotoDomain
import PhotoLibrary
import RoomDomain

/// 촬영 화면에 들어가기 전에 갖춰야 할 것을 한꺼번에 받는다 —
/// 방 목록·필터(목록과 LUT)·카메라 권한·사진첩 저장 권한.
///
/// 하나라도 어긋나면 카메라로 넘어가지 않는다 — 반쪽짜리 화면(목록 없음·색이 안 먹는 필터)을 띄우지 않기
/// 위해서다. 진입 버튼이 홈에도 방 상세에도 있어 두 피처가 이 한 벌을 함께 쓴다.
public struct ShootPreparation: Sendable {

    private let fetchShootableRooms: FetchShootableRoomsUseCase
    private let fetchFilters: FetchCameraFiltersUseCase
    private let prepareLUTs: PrepareCameraFiltersUseCase
    private let requestCameraPermission: RequestCameraPermissionUseCase
    private let photoLibraryPermission: PhotoLibraryPermissionClient

    /// 지금 의존성 컨텍스트에서 필요한 UseCase를 꺼내 온다 —
    /// 리듀서가 이펙트를 만들기 전에(= 이펙트 바깥에서) 한 번 만들어 넘긴다.
    public init() {
        @Dependency(\.fetchShootableRoomsUseCase) var fetchShootableRooms
        @Dependency(\.fetchCameraFiltersUseCase) var fetchFilters
        @Dependency(\.prepareCameraFiltersUseCase) var prepareLUTs
        @Dependency(\.requestCameraPermissionUseCase) var requestCameraPermission
        @Dependency(\.photoLibraryPermission) var photoLibraryPermission

        self.fetchShootableRooms = fetchShootableRooms
        self.fetchFilters = fetchFilters
        self.prepareLUTs = prepareLUTs
        self.requestCameraPermission = requestCameraPermission
        self.photoLibraryPermission = photoLibraryPermission
    }

    /// 권한 창이 뜨는 동안에도 조회는 계속 나가므로, 사용자가 허용을 누를 때쯤이면 목록이 이미 와 있다.
    ///
    /// 권한 거절을 조회 실패보다 먼저 보는 이유: 조회가 실패해도 사용자가 먼저 할 일은 권한 허용이다.
    /// 사진첩 권한까지 막는 이유: 촬영본은 사진첩에 저장한 뒤 업로드로 이어지므로,
    /// 저장 권한 없이 들어가면 셔터를 누르는 족족 실패한다.
    ///
    /// - Parameter roomID: 촬영 버튼을 누른 방. 카메라가 이 방을 고른 채로 열린다.
    /// - Returns: 준비 결과. 취소되면 `CancellationError`를 던진다 — 알릴 화면이 이미 없다.
    public func run(roomID: Room.ID) async throws -> Result<CameraEntry, ShootPreparationError> {
        /// 시스템 권한 팝업은 한 번에 하나만 뜬다 — 카메라를 먼저 묻고 이어서 사진첩을 묻는다.
        @Sendable func requestPermissions() async -> ShootPreparationError? {
            guard await requestCameraPermission.run() else { return .cameraPermissionDenied }
            // 저장만 하면 되므로 읽기 권한(.readWrite)까지는 요구하지 않는다.
            guard await photoLibraryPermission.request(.addOnly).allowsSaving else {
                return .photoLibraryPermissionDenied
            }
            return nil
        }

        /// 목록만으로는 촬영을 시작할 수 없다 — LUT까지 받아야 필터가 실제로 먹는다.
        /// 카메라 화면에서 받으면 필터 띠가 한동안 반쪽으로 뜨므로 여기서 함께 기다린다.
        @Sendable func prepareFilters() async throws -> [CameraFilter] {
            let filters = try await fetchFilters.run()
            try await prepareLUTs.run(filters)
            return filters
        }

        async let denial = requestPermissions()
        async let rooms = fetchShootableRooms.run()
        async let filters = prepareFilters()

        do {
            let entry = try await CameraEntry(roomID: roomID, rooms: rooms, filters: filters)
            if let denial = await denial {
                return .failure(denial)
            }
            return .success(entry)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if let denial = await denial {
                return .failure(denial)
            }
            return .failure(.loadFailed(message: error.entryMessage))
        }
    }
}
