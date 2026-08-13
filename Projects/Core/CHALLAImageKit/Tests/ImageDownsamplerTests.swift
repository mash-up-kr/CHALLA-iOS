@testable import CHALLAImageKit
import CoreGraphics
import Foundation
import Testing

/// ImageDownsampler의 픽셀 크기 계산·비율 유지·오류 처리 검증.
/// 픽스처는 TestImageFactory가 런타임 생성한다 (번들 리소스 불필요).
struct ImageDownsamplerTests {

    private let downsampler = ImageDownsampler()

    @Test("타깃보다 큰 이미지는 긴 변이 타깃 픽셀 이하이면서 근접하게 다운샘플된다")
    func downsamplesLargeImageToTargetMaxPixel() throws {
        let data = try TestImageFactory.jpegData(pixelWidth: 4000, pixelHeight: 3000)

        let result = try downsampler.downsample(
            data: data,
            pointSize: CGSize(width: 100, height: 100),
            scale: 3
        )

        // 기대 maxPixelSize = ceil(max(100, 100) * 3) = 300
        let longerSide = max(result.width, result.height)
        #expect(longerSide <= 300)
        #expect(longerSide >= 290, "타깃에 근접해야 한다 (과소 축소 금지)")
    }

    @Test("세로로 긴 이미지는 종횡비를 유지한 채 다운샘플된다")
    func preservesAspectRatioForPortraitImage() throws {
        let data = try TestImageFactory.jpegData(pixelWidth: 1500, pixelHeight: 2000)

        let result = try downsampler.downsample(
            data: data,
            pointSize: CGSize(width: 100, height: 100),
            scale: 2
        )

        #expect(result.height > result.width, "세로가 긴 원본은 결과도 세로가 길어야 한다")

        let originalRatio = 1500.0 / 2000.0
        let resultRatio = Double(result.width) / Double(result.height)
        #expect(abs(resultRatio - originalRatio) < 0.02, "종횡비 오차는 반올림 수준이어야 한다")
    }

    @Test("이미지가 아닌 손상 데이터는 invalidData를 던진다")
    func throwsInvalidDataForCorruptedData() {
        let corrupted = Data((0 ..< 1024).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) })

        #expect(throws: ImageDownsamplingError.invalidData) {
            try downsampler.downsample(
                data: corrupted,
                pointSize: CGSize(width: 100, height: 100),
                scale: 2
            )
        }
    }

    @Test("pointSize가 .zero면 invalidTargetSize를 던진다")
    func throwsInvalidTargetSizeForZeroPointSize() throws {
        let data = try TestImageFactory.jpegData(pixelWidth: 100, pixelHeight: 100)

        #expect(throws: ImageDownsamplingError.invalidTargetSize) {
            try downsampler.downsample(data: data, pointSize: .zero, scale: 2)
        }
    }

    @Test("scale이 0 이하면 invalidTargetSize를 던진다", arguments: [CGFloat.zero, -1])
    func throwsInvalidTargetSizeForNonPositiveScale(scale: CGFloat) throws {
        let data = try TestImageFactory.jpegData(pixelWidth: 100, pixelHeight: 100)

        #expect(throws: ImageDownsamplingError.invalidTargetSize) {
            try downsampler.downsample(
                data: data,
                pointSize: CGSize(width: 100, height: 100),
                scale: scale
            )
        }
    }

    @Test("타깃보다 작은 원본은 업스케일하지 않고 원본 픽셀 크기 그대로 반환한다")
    func doesNotUpscaleSmallerSource() throws {
        let data = try TestImageFactory.jpegData(pixelWidth: 120, pixelHeight: 80)

        // 기대 maxPixelSize = ceil(max(300, 300) * 2) = 600 — 원본(120)보다 크다
        let result = try downsampler.downsample(
            data: data,
            pointSize: CGSize(width: 300, height: 300),
            scale: 2
        )

        #expect(result.width == 120)
        #expect(result.height == 80)
    }
}
