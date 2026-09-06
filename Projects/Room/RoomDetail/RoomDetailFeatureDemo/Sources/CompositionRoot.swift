import ComposableArchitecture
import PhotoDomain
import PhotoLibrary
import RoomData
import RoomDomain

/// 의존성 조립 지점 — 데모앱에서 유일하게 Data 구현체를 만드는 곳.
///
/// 방 조회는 `InMemoryRoomRepository`를 쓴다. 사진 조회는 아직 Data 구현(PhotoData)이 없어
/// 여기서 값을 직접 만들어 넣는다 — 구현이 생기면 이 자리만 바꾸고 Feature는 손대지 않는다.
enum CompositionRoot {

    static func registerDetailDependencies(
        for state: DemoScreen.DetailState,
        into values: inout DependencyValues
    ) {
        let room = DemoSamples.room(for: state)
        let repository = InMemoryRoomRepository(
            cards: [RoomCard(room: room, memberCount: DemoSamples.members.count, thumbnailURLs: [])],
            inviteCodes: [DemoSamples.inviteCode: room.id],
            membersByRoom: [room.id: DemoSamples.members],
            // 실패를 심으면 상세·참여자 조회가 모두 던진다. 사진은 별개라 그대로 온다.
            failure: state == .error ? .network : nil
        )

        values.fetchRoomDetailUseCase = .live(repository: repository)
        values.checkPrintCompletionUseCase = .live(repository: repository)
        values.fetchRoomPhotosUseCase = FetchRoomPhotosUseCase(run: { _ in
            DemoSamples.photos(count: DemoSamples.photoCount(for: state))
        })
        values.saveAllPhotosUseCase = Self.stubSaveAllPhotos
        registerShootEntry(room: room, into: &values)
        // copyToPasteboard는 등록하지 않는다 — liveValue(실제 클립보드)가 그대로 쓰여
        // 데모에서 복사 후 붙여넣기까지 확인할 수 있다.
    }

    /// 사진첩 저장 없이 진행·완료 이벤트를 반환하는 데모 스텁.
    private static let stubSaveAllPhotos = SaveAllPhotosUseCase(run: { photos in
        AsyncStream { continuation in
            let task = Task {
                for index in photos.indices {
                    try? await Task.sleep(for: .milliseconds(120))
                    continuation.yield(
                        .progress(completed: index + 1, saved: index + 1, total: photos.count)
                    )
                }
                continuation.yield(.finished(saved: photos.count, failed: 0, total: photos.count))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    })

    /// 방 설정이 쓰는 의존성 — 이름 변경 하나뿐이다.
    /// InMemory 저장소에 방을 넣어 두어 "변경" 제출이 실서버처럼 성공한다.
    static func registerSettingsDependencies(room: Room, into values: inout DependencyValues) {
        let repository = InMemoryRoomRepository(
            cards: [RoomCard(room: room, memberCount: DemoSamples.members.count, thumbnailURLs: [])]
        )
        values.updateRoomTitleUseCase = .live(repository: repository)
    }

    /// 사진 찍기 버튼이 부르는 촬영 준비. 데모앱에는 카메라 화면이 없어 진입 요청(delegate)까지가 끝이다 —
    /// 버튼이 로딩으로 바뀌었다 풀리는 것까지만 확인할 수 있다.
    /// 권한은 값으로 갈아끼워 데모에서 실제 시스템 팝업이 뜨지 않게 한다.
    private static func registerShootEntry(room: Room, into values: inout DependencyValues) {
        values.fetchShootableRoomsUseCase = FetchShootableRoomsUseCase(run: {
            [
                ShootableRoom(
                    id: room.id,
                    title: room.title,
                    remainedPhotoCount: room.remainedPhotoCount,
                    totalPhotoCount: room.totalPhotoCount
                )
            ]
        })
        values.fetchCameraFiltersUseCase = FetchCameraFiltersUseCase(run: { CameraFilter.previewFilters })
        // LUT 원본은 서버에만 있다 — 데모는 필터 목록만 있으면 되므로 등록할 것이 없다.
        values.prepareCameraFiltersUseCase = PrepareCameraFiltersUseCase(run: { _ in })
        values.requestCameraPermissionUseCase = RequestCameraPermissionUseCase(run: { true })
        values.photoLibraryPermission.request = { _ in .authorized }
    }
}
