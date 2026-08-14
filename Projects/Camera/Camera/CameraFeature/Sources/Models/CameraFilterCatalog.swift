import ComposableArchitecture
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import os

/// 카메라가 제공하는 필름 LUT 필터 10종. id가 곧 번들 리소스 이름(`Resources/Filters/<id>.cube`)이다.
///
/// `CameraFilter`(리듀서 상태)는 표시 정보(id·이름)만 다루고, 실제 색 변환은 조립 지점
/// (데모앱·추후 CHALLAApp)의 카메라 세션이 이 카탈로그로 id를 LUT에 매핑해서 수행한다 —
/// 리듀서·뷰는 CoreImage를 모른다.
public enum CameraFilterCatalog {

    /// 화면 노출 순서. 이름은 기획 지정값, 주석은 원본 필름 스톡.
    public static let filters: IdentifiedArrayOf<CameraFilter> = [
        CameraFilter(id: "black", name: "Black"), // fuji_neopan_1600
        CameraFilter(id: "gray", name: "Gray"), // kodak_tri-x_400(-)
        CameraFilter(id: "cold", name: "Cold"), // polaroid_px-100uv+ cold
        CameraFilter(id: "blue", name: "Blue"), // polaroid_px-680 cold
        CameraFilter(id: "warm", name: "Warm"), // polaroid_px-680(+)
        CameraFilter(id: "old", name: "Old"), // fuji_fp-100c(-)
        CameraFilter(id: "forest", name: "Forest"), // polaroid_669(++)
        CameraFilter(id: "sky", name: "Sky"), // kodak_e-100 gx ektachrome
        CameraFilter(id: "green", name: "Green"), // fuji_superia_1600(++)
        CameraFilter(id: "soft", name: "Soft") // polaroid_polachrome
    ]

    /// id에 해당하는 LUT를 새 `CIColorCube` 인스턴스로 만든다. 없는 id면 nil (무필터 통과).
    ///
    /// `CIFilter` 인스턴스는 스레드 안전하지 않아 캐시하지 않고 호출마다 새로 만든다 —
    /// 프리뷰 프레임 큐와 촬영 경로가 같은 인스턴스를 공유하면 레이스가 난다.
    /// 대신 비싼 쪽인 .cube 텍스트 파싱(2,200행) 결과만 캐시한다.
    public static func lutFilter(id: CameraFilter.ID) -> (CIFilter & CIColorCubeWithColorSpace)? {
        guard let lut = cubeLUT(id: id) else { return nil }
        let filter = CIFilter.colorCubeWithColorSpace()
        filter.cubeDimension = lut.dimension
        filter.cubeData = lut.data
        filter.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        return filter
    }

    /// 촬영본 JPEG에 LUT를 입혀 다시 인코딩한다. 필터가 없거나 실패하면 nil (호출부가 원본 저장).
    public static func filteredJPEG(from data: Data, filterID: CameraFilter.ID?) -> Data? {
        guard let filterID,
              let lut = lutFilter(id: filterID),
              // EXIF 회전을 픽셀에 미리 굽는다 — LUT 출력을 새로 인코딩하면 원본 메타데이터가 사라진다
              let image = CIImage(data: data, options: [.applyOrientationProperty: true])
        else { return nil }

        lut.inputImage = image
        guard let output = lut.outputImage,
              let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        return jpegContext.jpegRepresentation(of: output, colorSpace: colorSpace)
    }

    /// JPEG 재인코딩용. `CIContext`는 스레드 안전(Apple 문서)하고 생성이 비싸 공유한다 —
    /// 구 SDK(CI의 Xcode)에는 Sendable 표기가 없어 nonisolated(unsafe)로 선언한다.
    private nonisolated(unsafe) static let jpegContext = CIContext()

    // MARK: - .cube 파싱

    /// 파싱된 LUT 원자료. `CIColorCube`가 요구하는 RGBA Float 배열 형태다.
    private struct CubeLUT: Sendable {
        let dimension: Float
        let data: Data
    }

    private static let cache = OSAllocatedUnfairLock<[CameraFilter.ID: CubeLUT]>(initialState: [:])

    private static func cubeLUT(id: CameraFilter.ID) -> CubeLUT? {
        if let cached = cache.withLock({ $0[id] }) {
            return cached
        }

        // 소스는 Resources/Filters/에 있지만 Tuist가 번들 루트로 평탄화한다 — subdirectory 없이 찾는다
        guard let url = Bundle.module.url(forResource: id, withExtension: "cube"),
              let parsed = parseCube(at: url)
        else {
            assertionFailure("필터 LUT 리소스 누락 또는 파싱 실패: \(id).cube")
            return nil
        }
        cache.withLock { $0[id] = parsed }
        return parsed
    }

    /// Adobe .cube 텍스트를 RGBA Float 배열로 바꾼다. 데이터 순서는 R이 가장 빨리 도는
    /// .cube 규격 그대로다 — `CIColorCube`도 같은 순서를 기대해서 재배열이 필요 없다.
    private static func parseCube(at url: URL) -> CubeLUT? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var dimension = 0
        var values: [Float] = []
        for rawLine in text.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }
            if line.hasPrefix("LUT_3D_SIZE") {
                dimension = line.split(separator: " ").last.flatMap { Int($0) } ?? 0
                values.reserveCapacity(dimension * dimension * dimension * 4)
                continue
            }
            if line.hasPrefix("TITLE") || line.hasPrefix("DOMAIN_") {
                continue
            }

            let parts = line.split(separator: " ")
            guard parts.count == 3,
                  let red = Float(parts[0]), let green = Float(parts[1]), let blue = Float(parts[2])
            else { return nil }
            values.append(contentsOf: [red, green, blue, 1])
        }

        guard dimension > 0, values.count == dimension * dimension * dimension * 4 else { return nil }
        return CubeLUT(
            dimension: Float(dimension),
            data: values.withUnsafeBufferPointer { Data(buffer: $0) }
        )
    }
}
