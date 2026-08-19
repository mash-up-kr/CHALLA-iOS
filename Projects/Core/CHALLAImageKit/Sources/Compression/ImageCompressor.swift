import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 파일 크기 상한이 있는 곳(서버 업로드 등)에 맞춰 이미지 바이트를 줄이는 압축기.
///
/// 상한 이하면 원본을 그대로 돌려주고(무손실), 넘으면 JPEG 품질을 단계적으로 낮춘 뒤
/// 그래도 크면 픽셀 크기까지 줄여 가며 상한 이하가 될 때까지 재인코딩한다.
/// 픽셀에 이미 구워진 내용(LUT 필터 등)은 재인코딩을 거쳐도 그대로 남는다.
///
/// 상태가 없는 값 타입이며, 동기 CPU 작업이므로 호출부가 백그라운드에서 실행할 책임을 진다.
public struct ImageCompressor: Sendable {

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// 이미지 바이트를 `maxBytes` 이하의 JPEG으로 만든다.
    ///
    /// - Parameters:
    ///   - data: ImageIO가 지원하는 포맷의 원본 바이트 (JPEG/PNG/HEIC…)
    ///   - maxBytes: 결과 크기 상한 (바이트)
    /// - Returns: 상한 이하면 원본 그대로, 넘으면 상한 이하로 재인코딩된 JPEG
    /// - Throws: ``ImageCompressionError``
    public func compress(data: Data, maxBytes: Int) throws -> Data {
        guard maxBytes > 0 else {
            throw ImageCompressionError.invalidLimit
        }
        guard data.count > maxBytes else { return data }

        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int,
              let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int,
              pixelWidth > 0, pixelHeight > 0
        else {
            throw ImageCompressionError.invalidData
        }

        var maxPixelSize = max(pixelWidth, pixelHeight)
        for _ in 0 ..< Const.maxDownscaleAttempts {
            let image = try decode(source: source, maxPixelSize: maxPixelSize)
            for quality in Const.qualityLadder {
                let encoded = try encodeJPEG(image, quality: quality)
                if encoded.count <= maxBytes {
                    return encoded
                }
            }
            maxPixelSize = max(Int(Double(maxPixelSize) * Const.downscaleFactor), 1)
        }
        throw ImageCompressionError.unableToFit
    }

    // MARK: - Private Methods

    /// 원본을 `maxPixelSize` 상한으로 디코딩한다. EXIF 회전을 픽셀에 굽는다 —
    /// JPEG 재인코딩 시 원본 메타데이터가 사라지므로 회전 정보를 남길 다른 방법이 없다.
    private func decode(source: CGImageSource, maxPixelSize: Int) throws -> CGImage {
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as [CFString: Any] as CFDictionary

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            throw ImageCompressionError.invalidData
        }
        return image
    }

    private func encodeJPEG(_ image: CGImage, quality: Double) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageCompressionError.encodingFailed
        }

        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageCompressionError.encodingFailed
        }
        return data as Data
    }

    private enum Const {
        /// 품질 하한을 0.4에 둔다 — 그 아래는 블록 노이즈가 눈에 띄어, 차라리 픽셀 축소가 낫다.
        static let qualityLadder: [Double] = [0.8, 0.6, 0.4]
        static let downscaleFactor = 0.7
        /// 0.7^10 ≈ 0.028 — 여기까지 줄여도 안 되는 입력은 정상 사진이 아니라고 보고 포기한다.
        static let maxDownscaleAttempts = 10
    }
}
