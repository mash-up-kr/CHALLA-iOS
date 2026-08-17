import ComposableArchitecture
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import os
import PhotoDomain

/// 서버에서 내려받은 필름 LUT의 등록소. 필터 목록·파일은 서버가 주고(`PhotoDomain`),
/// 여기는 내려받은 .cube 원자료를 파싱해 CoreImage 재료로 바꿔 보관만 한다.
///
/// `CameraFilter`(리듀서 상태)는 표시 정보(이름)만 다루고, 실제 색 변환은 조립 지점
/// (데모앱·추후 CHALLAApp)의 카메라 세션이 이 카탈로그로 id를 LUT에 매핑해서 수행한다 —
/// 리듀서·뷰는 CoreImage를 모른다.
public enum CameraFilterCatalog {

    /// 내려받은 .cube 원자료를 파싱해 등록한다. 성공 여부를 돌려준다 —
    /// 실패(깨진 파일 등)한 필터는 등록되지 않고 `lutFilter(id:)`가 nil을 줘 무보정 통과가 된다.
    @discardableResult
    public static func register(cubeData: Data, for id: CameraFilter.ID) -> Bool {
        guard let text = String(data: cubeData, encoding: .utf8),
              let parsed = parseCube(text: text)
        else { return false }
        cache.withLock { $0[id] = parsed }
        return true
    }

    /// id에 해당하는 LUT를 새 `CIColorCube` 인스턴스로 만든다. 미등록 id면 nil (무필터 통과).
    ///
    /// `CIFilter` 인스턴스는 스레드 안전하지 않아 캐시하지 않고 호출마다 새로 만든다 —
    /// 프리뷰 프레임 큐와 촬영 경로가 같은 인스턴스를 공유하면 레이스가 난다.
    /// 대신 비싼 쪽인 .cube 텍스트 파싱(수천 행) 결과만 캐시한다.
    public static func lutFilter(id: CameraFilter.ID) -> (CIFilter & CIColorCubeWithColorSpace)? {
        guard let lut = cache.withLock({ $0[id] }) else { return nil }
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

    /// Adobe .cube 텍스트를 RGBA Float 배열로 바꾼다. 데이터 순서는 R이 가장 빨리 도는
    /// .cube 규격 그대로다 — `CIColorCube`도 같은 순서를 기대해서 재배열이 필요 없다.
    private static func parseCube(text: String) -> CubeLUT? {
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
