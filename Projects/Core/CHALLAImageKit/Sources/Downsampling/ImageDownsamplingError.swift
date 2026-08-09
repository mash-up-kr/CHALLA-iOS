/// ``ImageDownsampler/downsample(data:pointSize:scale:)`` 실패 사유.
public enum ImageDownsamplingError: Error, Sendable, Equatable {
    /// 이미지 소스 생성 실패 — 디코딩 가능한 이미지 데이터가 아니다.
    case invalidData
    /// 소스는 유효하나 썸네일 생성에 실패했다 (예: 본문이 손상된 이미지).
    case thumbnailCreationFailed
    /// `pointSize` 또는 `scale`이 0 이하다.
    case invalidTargetSize
}
