import Photos

/// 촬영한 JPEG을 사진첩에 추가한다. `.addOnly` 권한만 요청한다 — 기존 사진을 읽거나 고를 필요는 없다.
enum PhotoLibrarySaver {

    enum SaveError: LocalizedError {
        case authorizationDenied

        var errorDescription: String? {
            "사진첩 접근 권한이 없어서 저장하지 못했어요."
        }
    }

    static func save(jpegData: Data) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw SaveError.authorizationDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: jpegData, options: nil)
        }
    }
}
