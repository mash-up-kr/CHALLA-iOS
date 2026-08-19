import Dependencies
import DependenciesMacros
import Photos

/// 요청할 접근 범위. 저장만 하면 되는 곳까지 읽기 권한을 요구하지 않으려고 나눠 둔다.
public enum PhotoLibraryAccessLevel: Sendable, Equatable {
    /// 사진첩에 추가만 한다 (`NSPhotoLibraryAddUsageDescription`)
    case addOnly
    /// 사진첩을 읽고 고른다 (`NSPhotoLibraryUsageDescription`)
    case readWrite
}

@DependencyClient
public struct PhotoLibraryPermissionClient: Sendable {
    public var request: @Sendable (PhotoLibraryAccessLevel) async -> PhotoLibraryAuthorization = { _ in .denied }
}

extension PhotoLibraryPermissionClient: DependencyKey {

    public static let liveValue = PhotoLibraryPermissionClient(
        request: { level in
            await PhotoLibraryAuthorization(PHPhotoLibrary.requestAuthorization(for: level.phAccessLevel))
        }
    )

    public static let testValue = PhotoLibraryPermissionClient()

    public static let previewValue = PhotoLibraryPermissionClient(request: { _ in .authorized })
}

private extension PhotoLibraryAccessLevel {

    var phAccessLevel: PHAccessLevel {
        switch self {
        case .addOnly: .addOnly
        case .readWrite: .readWrite
        }
    }
}

public extension DependencyValues {
    var photoLibraryPermission: PhotoLibraryPermissionClient {
        get { self[PhotoLibraryPermissionClient.self] }
        set { self[PhotoLibraryPermissionClient.self] = newValue }
    }
}
