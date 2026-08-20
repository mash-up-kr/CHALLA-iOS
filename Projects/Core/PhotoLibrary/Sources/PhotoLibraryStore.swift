import Foundation
import Photos

/// 기기 사진첩에 이미지를 추가한다. 권한 요청까지 여기서 끝낸다.
///
/// 저장만 하므로 읽기 권한은 요청하지 않는다 — `.addOnly`면 충분하다.
public struct PhotoLibraryStore: Sendable {

    public init() {}

    public func save(imageData: Data) async throws {
        // 이미 결정된 상태면 팝업 없이 그 값이 바로 돌아온다.
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryError.permissionDenied
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                // 원본 바이트 그대로 — UIImage로 만들면 메타데이터가 날아가고 재인코딩된다.
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: imageData, options: nil)
            }
        } catch {
            throw PhotoLibraryError.saveFailed
        }
    }
}
