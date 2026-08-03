import CoreGraphics
import Foundation
import ImageIO

/// 원본 이미지 바이트를 뷰 표시에 필요한 픽셀 크기로만 디코딩하는 다운샘플러.
///
/// `UIImage(data:)`로 원본 전체를 디코딩하면 4000×3000 사진 한 장이 약 45MB 메모리를
/// 차지한다. 이 타입은 ImageIO의 썸네일 디코딩(`CGImageSourceCreateThumbnailAtIndex`)으로
/// 타깃 픽셀 크기만큼만 디코딩해 그리드/셀 표시 시 메모리 사용량을 크게 줄인다.
///
/// 상태가 없는 값 타입이며, 동기 CPU 작업이므로 호출부(로더)가 백그라운드에서 실행할 책임을 진다.
public struct ImageDownsampler: Sendable {

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// 원본 이미지 데이터를 타깃 픽셀 크기에 맞춰 썸네일 CGImage로 디코딩한다.
    ///
    /// 적용 옵션:
    /// - `kCGImageSourceCreateThumbnailFromImageAlways` — 내장 썸네일 유무와 무관하게 항상 생성
    /// - `kCGImageSourceShouldCacheImmediately` — 생성 시점에 즉시 디코딩(표시 시점 히치 방지)
    /// - `kCGImageSourceCreateThumbnailWithTransform` — EXIF 회전 반영
    /// - `kCGImageSourceThumbnailMaxPixelSize` — `ceil(max(pointSize.width, pointSize.height) * scale)`
    ///
    /// 원본이 타깃보다 작으면 업스케일하지 않고 원본 크기 그대로 반환한다(ImageIO 동작).
    ///
    /// - Parameters:
    ///   - data: ImageIO가 지원하는 포맷의 원본 바이트 (JPEG/PNG/HEIC…)
    ///   - pointSize: 뷰의 논리 크기(pt)
    ///   - scale: 디스플레이 배율 (@2x/@3x)
    /// - Returns: 다운샘플된 CGImage — 긴 변이 `ceil(max(pointSize) * scale)` 픽셀 이하
    /// - Throws: ``ImageDownsamplingError``
    public func downsample(data: Data, pointSize: CGSize, scale: CGFloat) throws -> CGImage {
        guard pointSize.width > 0, pointSize.height > 0, scale > 0 else {
            throw ImageDownsamplingError.invalidTargetSize
        }

        // 원본 전체 디코딩 결과를 소스에 캐시하지 않는다 — 썸네일만 필요하다.
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              CGImageSourceGetCount(source) > 0
        else {
            throw ImageDownsamplingError.invalidData
        }

        // ThumbnailMaxPixelSize는 "상한"이라 원본이 이보다 작으면 ImageIO가 원본 크기를 유지한다(업스케일 안 함).
        let maxPixelSize = Int(ceil(max(pointSize.width, pointSize.height) * scale))
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as [CFString: Any] as CFDictionary

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            throw ImageDownsamplingError.thumbnailCreationFailed
        }
        return thumbnail
    }
}
