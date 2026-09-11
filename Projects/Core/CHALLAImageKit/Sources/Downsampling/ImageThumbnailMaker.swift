import CoreGraphics
import Foundation

/// 업로드용 축소본을 만든다 — 원본 바이트를 받아 긴 변이 상한 이하인 JPEG로 돌려준다.
///
/// 목록·필름처럼 작게 보이는 화면이 원본(장당 4~4.5MB)을 통째로 받지 않도록,
/// 사진을 올릴 때 축소본도 같이 만들어 함께 올린다.
///
/// 다운샘플과 인코딩은 로더가 쓰는 것과 같은 경로를 탄다 — 포맷 정책(JPEG·화질)이
/// 한 곳에만 있도록 이 타입을 창구로 둔다.
///
/// 상태가 없는 값 타입이며, 동기 CPU 작업이므로 호출부가 백그라운드에서 실행할 책임을 진다.
public struct ImageThumbnailMaker: Sendable {

    // MARK: - Properties

    private let downsampler = ImageDownsampler()
    private let encoder = ImageDataEncoder()

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// 원본 바이트를 긴 변 `maxPixelSize` 이하의 JPEG으로 줄인다.
    ///
    /// 원본이 상한보다 작으면 확대하지 않고 그 크기 그대로 다시 인코딩한다(ImageIO 동작).
    ///
    /// - Parameters:
    ///   - data: ImageIO가 지원하는 포맷의 원본 바이트 (JPEG/PNG/HEIC…)
    ///   - maxPixelSize: 결과의 긴 변 상한(픽셀)
    /// - Throws: ``ImageDownsamplingError`` 또는 ``ImageLoadingError/encodingFailed``
    public func thumbnailJPEG(from data: Data, maxPixelSize: CGFloat) throws -> Data {
        let cgImage = try downsampler.downsample(
            data: data,
            pointSize: CGSize(width: maxPixelSize, height: maxPixelSize),
            scale: 1
        )
        return try encoder.encode(cgImage)
    }
}
