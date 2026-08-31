@testable import CameraFeature
import CoreImage
import Foundation
import ImageIO
import Testing

// MARK: - LUT 등록

/// 등록 성공 여부가 카메라 진입 여부를 가른다 — 진입 버튼이 이 반환값으로 판단한다.
struct CameraFilterCatalogTests {

    @Test("정상 .cube는 등록되고 필터를 만들 수 있다")
    func registersValidCube() {
        let id = "정상필터"

        #expect(CameraFilterCatalog.register(cubeData: Data(CameraFeatureTestFixtures.validCubeText.utf8), for: id))
        #expect(CameraFilterCatalog.lutFilter(id: id) != nil)
    }

    @Test("깨진 .cube는 등록되지 않는다")
    func rejectsBrokenCube() {
        let id = "깨진필터"

        #expect(!CameraFilterCatalog.register(cubeData: Data("깨진 파일".utf8), for: id))
        #expect(CameraFilterCatalog.lutFilter(id: id) == nil)
    }

    @Test("필터 인코딩 품질을 최대로 명시해 CIContext 기본값보다 높게 굽는다")
    func encodesAboveContextDefaultQuality() throws {
        let id = "품질확인필터"
        CameraFilterCatalog.register(cubeData: Data(Self.identityCubeText.utf8), for: id)
        let source = try #require(Self.noiseJPEG())

        let filtered = try #require(CameraFilterCatalog.filteredJPEG(from: source, filterID: id))
        let contextDefault = try #require(Self.encodeWithLUT(source: source, id: id, quality: nil))

        // 품질을 안 넘기면 기본값(측정상 0.75)이 걸려 업로드 압축 전에 화질이 깎인다.
        #expect(filtered.count > contextDefault.count)
        #expect(filtered == Self.encodeWithLUT(source: source, id: id, quality: 1.0))
    }

    /// 입출력이 그대로인 2x2x2 LUT. 전 채널 0인 `validCubeText`는 결과가 검은 이미지라
    /// JPEG 크기 비교가 무의미해져서 이 테스트에서는 쓰지 않는다.
    private static let identityCubeText = """
    LUT_3D_SIZE 2
    0 0 0
    1 0 0
    0 1 0
    1 1 0
    0 0 1
    1 0 1
    0 1 1
    1 1 1
    """

    /// 품질 차이가 바이트 수로 드러나려면 평탄한 색 대신 고주파 성분이 필요하다.
    private static func noiseJPEG() -> Data? {
        guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        let cropped = noise.cropped(to: CGRect(x: 0, y: 0, width: 256, height: 256))
        return CIContext().jpegRepresentation(of: cropped, colorSpace: colorSpace, options: [
            .init(rawValue: kCGImageDestinationLossyCompressionQuality as String): 1.0
        ])
    }

    /// `filteredJPEG`과 같은 경로를 타되 인코딩 품질만 바꿔 기준선을 만든다.
    private static func encodeWithLUT(source: Data, id: String, quality: Double?) -> Data? {
        guard let lut = CameraFilterCatalog.lutFilter(id: id),
              let image = CIImage(data: source, options: [.applyOrientationProperty: true])
        else { return nil }
        lut.inputImage = image
        guard let output = lut.outputImage,
              let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }

        let context = CIContext()
        guard let quality else {
            return context.jpegRepresentation(of: output, colorSpace: colorSpace)
        }
        return context.jpegRepresentation(of: output, colorSpace: colorSpace, options: [
            .init(rawValue: kCGImageDestinationLossyCompressionQuality as String): quality
        ])
    }
}
