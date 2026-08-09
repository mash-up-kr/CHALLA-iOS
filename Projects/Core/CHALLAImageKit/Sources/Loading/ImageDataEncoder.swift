import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 다운샘플된 `CGImage`를 디스크 저장용 바이트로 재인코딩한다.
///
/// 디스크 캐시에는 원본이 아니라 "이미 다운샘플된" 픽셀만 담기므로, 그 픽셀을 파일로 쓰기 위한
/// 인코딩 단계가 필요하다. 포맷은 HEIC를 쓴다(같은 화질 대비 JPEG보다 파일이 작아 디스크 절약).
///
/// 별도 타입으로 분리한 이유: 포맷 정책(HEIC ↔ JPEG/PNG 등)을 한 곳에서 교체하기 위한 지점이다.
struct ImageDataEncoder: Sendable {

    // MARK: - Public Methods

    /// `CGImage`를 HEIC 바이트로 인코딩한다.
    ///
    /// 알파(투명도) 주의: HEIC 인코딩 경로에서 알파 채널이 보존되지 않아 손실될 수 있다.
    /// CHALLA는 불투명한 필름 사진이 중심이라 v1에서는 이 손실을 수용한다.
    /// 투명 이미지 지원이 필요해지면 이 타입에서 포맷을 교체한다.
    ///
    /// - Throws: 인코딩 실패 시 ``ImageLoadingError/encodingFailed``.
    func encode(_ cgImage: CGImage) throws -> Data {
        let data = NSMutableData()
        // iOS 17에서 HEIC를 지원한다("public.heic").
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageLoadingError.encodingFailed
        }

        CGImageDestinationAddImage(destination, cgImage, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageLoadingError.encodingFailed
        }
        return data as Data
    }
}
