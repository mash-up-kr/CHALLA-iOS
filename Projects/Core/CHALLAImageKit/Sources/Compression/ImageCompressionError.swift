/// ``ImageCompressor/compress(data:maxBytes:)`` 실패 사유.
public enum ImageCompressionError: Error, Sendable, Equatable {
    /// 디코딩 가능한 이미지 데이터가 아니다.
    case invalidData
    /// `maxBytes`가 0 이하다.
    case invalidLimit
    /// JPEG 인코딩 실패.
    case encodingFailed
    /// 품질·픽셀 축소를 반복해도 상한 이하로 줄이지 못했다.
    case unableToFit
}
