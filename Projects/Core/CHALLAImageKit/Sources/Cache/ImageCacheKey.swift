import CryptoKit
import Foundation

/// 이미지 캐시의 조회 단위. `URL`과 표시 픽셀 크기의 조합으로 캐시 항목을 식별한다.
///
/// 같은 URL이라도 표시 크기가 다르면 다른 이미지이므로(그리드 300px vs 상세 1200px),
/// 키에는 URL과 픽셀 크기가 함께 들어간다.
public struct ImageCacheKey: Hashable, Sendable {

    public let url: URL
    public let pixelSize: PixelSize

    public init(url: URL, pixelSize: PixelSize) {
        self.url = url
        self.pixelSize = pixelSize
    }

    /// 디스크 캐시 파일명으로 쓸 안전한 식별자.
    /// URL에는 파일명에 못 쓰는 문자(`/`, `?` 등)가 있으므로 SHA256 16진수 문자열로 변환한다.
    public var storageIdentifier: String {
        let raw = "\(url.absoluteString)|\(pixelSize.width)x\(pixelSize.height)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
