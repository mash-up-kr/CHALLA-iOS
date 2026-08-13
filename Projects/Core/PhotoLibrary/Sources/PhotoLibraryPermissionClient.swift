import Dependencies
import DependenciesMacros
import Photos

/// 사진 라이브러리 접근 권한의 조회·요청.
///
/// 피커 화면은 담지 않는다 — 사진을 고르는 UI는 SwiftUI `PhotosPicker`가 그리고,
/// 이 모듈은 그 앞단의 권한만 책임진다.
@DependencyClient
public struct PhotoLibraryPermissionClient: Sendable {
    /// 미결정이면 시스템 팝업을 띄우고, 이미 결정된 상태면 그대로 돌려준다.
    public var request: @Sendable () async -> PhotoLibraryAuthorization = { .denied }
}

extension PhotoLibraryPermissionClient: DependencyKey {

    /// `.readWrite`로 묻는 이유: 프로필 사진은 읽기만 하지만, `.addOnly`는 읽기 권한을 주지 않는다.
    public static let liveValue = PhotoLibraryPermissionClient(
        request: {
            await PhotoLibraryAuthorization(PHPhotoLibrary.requestAuthorization(for: .readWrite))
        }
    )

    public static let testValue = PhotoLibraryPermissionClient()

    public static let previewValue = PhotoLibraryPermissionClient(request: { .authorized })
}

public extension DependencyValues {
    var photoLibraryPermission: PhotoLibraryPermissionClient {
        get { self[PhotoLibraryPermissionClient.self] }
        set { self[PhotoLibraryPermissionClient.self] = newValue }
    }
}
