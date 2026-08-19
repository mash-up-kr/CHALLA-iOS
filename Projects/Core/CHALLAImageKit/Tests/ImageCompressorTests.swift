@testable import CHALLAImageKit
import CoreGraphics
import Foundation
import ImageIO
import Testing

/// ImageCompressor의 상한 준수·무손실 통과·오류 처리 검증.
/// 픽스처는 TestImageFactory가 런타임 생성한다 (번들 리소스 불필요).
struct ImageCompressorTests {

    private let compressor = ImageCompressor()

    @Test("상한 이하의 데이터는 재인코딩 없이 그대로 돌려준다")
    func passesThroughDataWithinLimit() throws {
        let data = try TestImageFactory.jpegData(pixelWidth: 200, pixelHeight: 200)

        let result = try compressor.compress(data: data, maxBytes: data.count)

        #expect(result == data)
    }

    @Test("상한을 넘는 이미지는 상한 이하의 디코딩 가능한 JPEG이 된다")
    func compressesOversizedImageUnderLimit() throws {
        let data = try TestImageFactory.noiseJPEGData(pixelWidth: 1200, pixelHeight: 1200)
        let maxBytes = data.count / 4

        let result = try compressor.compress(data: data, maxBytes: maxBytes)

        #expect(result.count <= maxBytes)
        let source = try #require(CGImageSourceCreateWithData(result as CFData, nil))
        #expect(CGImageSourceGetType(source) == "public.jpeg" as CFString)
        #expect(CGImageSourceCreateImageAtIndex(source, 0, nil) != nil)
    }

    @Test("품질 저하만으로 부족하면 픽셀 크기를 줄여서라도 상한을 맞춘다")
    func downscalesWhenQualityAloneIsNotEnough() throws {
        let data = try TestImageFactory.noiseJPEGData(pixelWidth: 1200, pixelHeight: 1200)
        let maxBytes = 50 * 1024 // 노이즈 1200px는 품질 하한(0.4)으로도 못 맞추는 크기

        let result = try compressor.compress(data: data, maxBytes: maxBytes)

        #expect(result.count <= maxBytes)
        let source = try #require(CGImageSourceCreateWithData(result as CFData, nil))
        let properties = try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        #expect(width < 1200)
    }

    @Test("이미지가 아닌 바이트는 invalidData를 던진다")
    func throwsOnNonImageData() {
        let garbage = Data(repeating: 0xAB, count: 1024)

        #expect(throws: ImageCompressionError.invalidData) {
            _ = try compressor.compress(data: garbage, maxBytes: 512)
        }
    }

    @Test("상한이 0 이하이면 invalidLimit을 던진다")
    func throwsOnNonPositiveLimit() {
        #expect(throws: ImageCompressionError.invalidLimit) {
            _ = try compressor.compress(data: Data([0x01]), maxBytes: 0)
        }
    }
}
