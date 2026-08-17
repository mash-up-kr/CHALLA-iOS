import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 다운샘플된 `CGImage`를 디스크 저장용 바이트로 재인코딩한다.
///
/// 디스크 캐시에는 원본이 아니라 "이미 다운샘플된" 픽셀만 담기므로, 그 픽셀을 파일로 쓰기 위한
/// 인코딩 단계가 필요하다.
///
/// 포맷은 JPEG를 쓴다. HEIC가 같은 화질 대비 파일은 작지만, 인코딩·디코딩이 HEVC 코덱을 거친다.
/// 시뮬레이터에는 하드웨어 HEVC가 없어 여러 장을 동시에 처리하면 코덱 세션에서 멈추고,
/// 그 사이 모든 이미지 로드가 응답하지 않는다 (방 상세 그리드에서 사진이 한 장도 뜨지 않던 원인, #57).
///
/// 별도 타입으로 분리한 이유: 포맷 정책(JPEG ↔ HEIC/PNG 등)을 한 곳에서 교체하기 위한 지점이다.
struct ImageDataEncoder: Sendable {

    // MARK: - Public Methods

    /// `CGImage`를 JPEG 바이트로 인코딩한다.
    ///
    /// 알파(투명도) 주의: JPEG는 알파 채널을 담지 못한다.
    /// CHALLA는 불투명한 필름 사진이 중심이라 v1에서는 이 손실을 수용한다.
    /// 투명 이미지 지원이 필요해지면 이 타입에서 포맷을 교체한다.
    ///
    /// - Throws: 인코딩 실패 시 ``ImageLoadingError/encodingFailed``.
    func encode(_ cgImage: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageLoadingError.encodingFailed
        }

        // 화질 0.9 — 다운샘플된 썸네일이라 이 값에서 눈에 띄는 손실이 없다.
        CGImageDestinationAddImage(destination, cgImage, [
            kCGImageDestinationLossyCompressionQuality: Metric.compressionQuality
        ] as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageLoadingError.encodingFailed
        }
        return data as Data
    }
}

// MARK: - 인코딩 설정

private enum Metric {
    static let compressionQuality: CGFloat = 0.9
}
