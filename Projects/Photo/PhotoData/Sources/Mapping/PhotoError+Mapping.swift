import CHALLANetwork
import Foundation
import PhotoDomain

extension PhotoError {

    /// 계층을 넘어온 오류를 도메인 오류로 정규화한다 (`RoomError.normalized`와 같은 구조).
    /// 취소는 그대로 통과시킨다 — 호출자가 "실패 토스트를 띄울 오류"와 구분해야 한다.
    static func normalized(_ error: any Error) -> any Error {
        switch error {
        case is CancellationError:
            return error
        case let photoError as PhotoError:
            return photoError // unwrap·매핑이 던진 도메인 오류 그대로
        case let networkError as NetworkError:
            return PhotoError(networkError: networkError)
        default:
            return PhotoError.unknown
        }
    }

    /// 네트워크 계층의 실패를 사진 도메인의 실패로 바꾸는 번역표.
    /// TODO: 백엔드 확인 — 스웨거에 에러 응답 정의가 없어 409 매핑은 잠정이다.
    ///       (장수 소진 방 업로드의 실제 상태 코드와 에러 바디 형식 확인 후 확정)
    init(networkError: NetworkError) {
        switch networkError {
        case .transport:
            self = .network
        case let .unacceptableStatusCode(statusCode, _):
            switch statusCode {
            case 401: self = .unauthorized
            case 409: self = .photoExhausted
            default: self = .server(message: "요청이 실패했어요. (HTTP \(statusCode))")
            }
        case .invalidRequest, .nonHTTPResponse, .decoding:
            self = .unknown
        }
    }
}
