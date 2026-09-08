import CHALLAImageKit
import Dependencies
import DependenciesMacros
import UIKit

/// 고른 사진을 카드 표시 크기의 JPEG로 줄인다 — 원본을 그대로 두면 방마다 수 MB가 쌓이고 카드가 매번 전체를 디코딩한다.
/// 동기 CPU 작업이라 리듀서가 `.run` 안에서 부른다.
@DependencyClient
struct CoverImageEncoder: Sendable {
    var encode: @Sendable (Data) throws -> Data
}

enum CoverImageEncodingError: Error, Equatable, Sendable {
    case encodingFailed
}

extension CoverImageEncoder: DependencyKey {

    /// liveValue를 바로 채운다 — Data 접근이 없어 합성 루트가 조립할 것이 없다.
    static let liveValue = CoverImageEncoder { data in
        let image = try ImageDownsampler().downsample(data: data, pointSize: Const.pointSize, scale: Const.scale)
        guard let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: Const.compressionQuality) else {
            throw CoverImageEncodingError.encodingFailed
        }
        return jpeg
    }

    static let testValue = CoverImageEncoder()

    static let previewValue = CoverImageEncoder { $0 }
}

extension DependencyValues {
    var coverImageEncoder: CoverImageEncoder {
        get { self[CoverImageEncoder.self] }
        set { self[CoverImageEncoder.self] = newValue }
    }
}

private enum Const {
    /// 카드(200×266)의 2배 — 상세·홈 카드가 더 크게 그려도 흐려지지 않을 여유.
    static let pointSize = CGSize(width: 400, height: 532)
    /// 기기 배율이 아니라 최대 배율로 고정한다. 한 번 저장한 파일을 기기 이전 뒤에도 그대로 쓰기 위해서다.
    static let scale: CGFloat = 3
    static let compressionQuality: CGFloat = 0.85
}
