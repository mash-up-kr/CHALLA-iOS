import CameraFeature // CameraFilterCatalog — 진입 전에 LUT를 등록해 둔다
import CHALLAImageKit
import CHALLANetwork
import ComposableArchitecture
import PhotoData
import PhotoDomain
import PhotoLibrary
import RoomDetailFeature // PrintNoticeFilmMetric — 미리 받기가 필름과 같은 크기를 써야 한다
import UIKit

/// 사진 배선만 따로 둔다 — CompositionRoot 본체가 타입 길이 제한(250줄)을 넘었다.
extension CompositionRoot {

    /// client 공유 조건은 registerUser와 같다. 카메라 화면이 앱에 조립되면 이 배선을 그대로 쓴다.
    static func registerPhoto(
        into values: inout DependencyValues,
        client: any HTTPClient,
        imageLoader: ImageLoader?
    ) {
        let photoRepository = DefaultPhotoRepository(client: client)
        let filterRepository = DefaultCameraFilterRepository(client: client)
        let uploader = DefaultPhotoUploader(client: client)
        // 안내 노출 기록만 서버가 아니라 기기에 남는다 (`CameraOnboardingRepository` 주석 참고).
        let onboarding = DefaultCameraOnboardingRepository()
        let cameraPermission = SystemCameraPermissionProvider()

        // 사진 조회·리액션·저장 — 방 상세 그리드와 사진 상세가 함께 쓴다.
        values.fetchRoomPhotosUseCase = .live(repository: photoRepository)
        // 리액션은 목록에 없어 사진을 펼칠 때 한 장씩 지연 조회한다(1+N 회피).
        values.fetchPhotoReactionsUseCase = .live(repository: photoRepository)
        values.setPhotoReactionUseCase = .live(repository: photoRepository)
        values.deletePhotoReactionUseCase = .live(repository: photoRepository)
        values.savePhotoUseCase = .live(repository: photoRepository, photoLibrary: PhotoLibraryWritingAdapter())
        values.saveAllPhotosUseCase = .live(repository: photoRepository, photoLibrary: PhotoLibraryWritingAdapter())

        // 홈이 인화 완료 방의 사진을 미리 받아 둔다. 필름이 쓰는 것과 같은 로더·같은 크기여야
        // 캐시가 맞는다 — 크기가 어긋나면 미리 받은 것이 통째로 버려진다.
        // 배율은 부를 때 읽는다. 조립 시점에는 아직 화면이 없어 값이 확정되지 않는다.
        if let imageLoader {
            values.prefetchRoomPhotosUseCase = .live(
                repository: photoRepository,
                loader: imageLoader,
                pointSize: PrintNoticeFilmMetric.photoPointSize,
                scale: { await MainActor.run { UITraitCollection.current.displayScale } }
            )
        }

        values.fetchCameraFiltersUseCase = .live(repository: filterRepository)
        values.prepareCameraFiltersUseCase = .live(
            repository: filterRepository,
            register: CameraFilterCatalog.register(cubeData:for:)
        )
        values.uploadPhotoUseCase = .live(uploader: uploader)
        values.shouldShowCameraCoachMarkUseCase = .live(repository: onboarding)
        values.markCameraCoachMarkSeenUseCase = .live(repository: onboarding)
        values.requestCameraPermissionUseCase = .live(permission: cameraPermission)
        values.openCameraSettingsUseCase = .live(permission: cameraPermission)
    }
}

/// Core의 사진첩 저장(`PhotoLibraryStore`)을 도메인 인터페이스(`PhotoLibraryWriting`)에 연결한다.
/// Core는 도메인을 모르므로(`Keychain`과 같은 이유) 앱에서 어댑터로 오류를 `PhotoError`로 바꿔 준다.
private struct PhotoLibraryWritingAdapter: PhotoLibraryWriting {

    private let store = PhotoLibraryStore()

    func save(imageData: Data) async throws {
        do {
            try await store.save(imageData: imageData)
        } catch PhotoLibraryError.permissionDenied {
            throw PhotoError.permissionDenied
        } catch is CancellationError {
            // 화면 이탈로 끊긴 것이라 실패로 세면 안 된다 — 호출부가 취소를 구분해 멈춘다.
            throw CancellationError()
        } catch {
            throw PhotoError.saveFailed
        }
    }
}
