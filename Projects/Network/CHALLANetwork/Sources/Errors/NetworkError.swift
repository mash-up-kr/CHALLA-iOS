import Foundation

/// 네트워크 계층에서 발생 가능한 오류.
///
/// Data 레이어는 이 오류를 잡아 도메인 오류(`AppError` 등)로 매핑한다.
/// Feature·Domain은 이 타입의 존재를 알 필요가 없다 (아키텍처 규칙 6).
public enum NetworkError: Error {

    /// Endpoint → URLRequest 변환 실패 (잘못된 URL, 인코딩 실패 등).
    case invalidRequest(reason: String)

    /// 전송 자체가 실패 (오프라인, 타임아웃, 연결 끊김 등). `URLSession`이 던진 오류를 감싼다.
    case transport(underlying: Error)

    /// 응답이 `HTTPURLResponse`가 아님 (정상적인 HTTP 통신에서는 발생하지 않음).
    case nonHTTPResponse

    /// 허용 범위(기본 `200..<300`) 밖의 상태 코드.
    case unacceptableStatusCode(statusCode: Int, response: Response)

    /// 응답 본문 디코딩 실패.
    case decoding(underlying: Error, response: Response)
}

// TODO: 추후 디자인에 맞춰 수정
extension NetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidRequest(reason):
            return "요청을 만들 수 없습니다: \(reason)"
        case let .transport(underlying):
            return "네트워크 전송에 실패했습니다: \(underlying.localizedDescription)"
        case .nonHTTPResponse:
            return "HTTP 응답이 아닙니다."
        case let .unacceptableStatusCode(statusCode, _):
            return "허용되지 않은 상태 코드입니다: \(statusCode)"
        case let .decoding(underlying, _):
            return "응답을 해석할 수 없습니다: \(underlying.localizedDescription)"
        }
    }
}
