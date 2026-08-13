import Foundation

/// ``ImageLoader/image(from:pointSize:scale:)`` 실패 사유.
///
/// 파이프라인(메모리 → 디스크 → 네트워크 → 다운샘플/인코딩) 각 단계의 실패를 하나의 타입으로 모은다.
public enum ImageLoadingError: Error, Sendable, Equatable {

    /// 응답이 `HTTPURLResponse`가 아니다.
    case invalidResponse

    /// HTTP 상태 코드가 성공 범위(`200..<300`)를 벗어났다. 연관값은 실제 상태 코드.
    case httpStatus(Int)

    /// 응답 본문이 0바이트다.
    case emptyData

    /// 다운샘플링 단계 실패. 연관값은 원인 ``ImageDownsamplingError``.
    case downsampling(ImageDownsamplingError)

    /// 디스크 저장용 재인코딩(HEIC) 실패.
    case encodingFailed

    /// 서버 응답을 받기 전 네트워크 전송 자체가 실패했다(오프라인·타임아웃·연결 끊김 등).
    /// 응답은 왔으나 상태가 나쁜 ``httpStatus(_:)`` 와 구분된다. 연관값은 `URLError`의 코드.
    case networkFailed(URLError.Code)

    /// 작업이 취소되었다.
    case cancelled
}
