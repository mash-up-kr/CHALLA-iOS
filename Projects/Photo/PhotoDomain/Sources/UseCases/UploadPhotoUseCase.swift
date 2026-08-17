import Dependencies
import DependenciesMacros
import Foundation

/// 촬영한 사진을 방에 올리고 그 방의 남은 장수를 돌려받는다.
///
/// `liveValue`가 없는 이유는 `FetchCameraFiltersUseCase` 주석 참고.
@DependencyClient
public struct UploadPhotoUseCase: Sendable {
    public var run: @Sendable (_ jpegData: Data, _ roomID: Int64, _ filterName: String) async throws -> Int
}

extension UploadPhotoUseCase: TestDependencyKey {

    public static func live(uploader: any PhotoUploader) -> UploadPhotoUseCase {
        UploadPhotoUseCase(run: { jpegData, roomID, filterName in
            try await uploader.upload(jpegData: jpegData, roomID: roomID, filterName: filterName)
        })
    }

    public static let testValue = UploadPhotoUseCase()

    public static let previewValue = UploadPhotoUseCase(
        run: { _, _, _ in 5 }
    )
}

public extension DependencyValues {
    var uploadPhotoUseCase: UploadPhotoUseCase {
        get { self[UploadPhotoUseCase.self] }
        set { self[UploadPhotoUseCase.self] = newValue }
    }
}
