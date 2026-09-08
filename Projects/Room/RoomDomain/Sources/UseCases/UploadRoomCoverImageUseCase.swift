import Dependencies
import DependenciesMacros
import Foundation

/// 커버 저장과 분리한 이유: 업로드는 수 초가 걸려, 그 사이 고른 스티커·색이 사진 저장에 덮이지 않으려면
/// URL을 받은 뒤 그 시점의 커버로 저장해야 한다.
@DependencyClient
public struct UploadRoomCoverImageUseCase: Sendable {
    public var run: @Sendable (_ imageData: Data) async throws -> URL
}

extension UploadRoomCoverImageUseCase: TestDependencyKey {

    public static func live(uploader: any RoomCoverImageUploader) -> UploadRoomCoverImageUseCase {
        UploadRoomCoverImageUseCase(run: { data in
            try await uploader.upload(data)
        })
    }

    public static let testValue = UploadRoomCoverImageUseCase()

    public static let previewValue = UploadRoomCoverImageUseCase(run: { _ in
        URL(string: "https://example.com/cover/preview.jpg")!
    })
}

public extension DependencyValues {
    var uploadRoomCoverImageUseCase: UploadRoomCoverImageUseCase {
        get { self[UploadRoomCoverImageUseCase.self] }
        set { self[UploadRoomCoverImageUseCase.self] = newValue }
    }
}
