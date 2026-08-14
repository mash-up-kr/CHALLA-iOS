import CHALLANetwork
import Foundation
import NotificationDomain

extension NotificationError {

    /// 계층을 넘어온 오류를 도메인 오류로 정규화한다.
    /// 취소는 그대로 통과시킨다 — 화면 이탈로 이펙트가 끊긴 것과 실제 실패를 호출자가 구분해야 한다.
    static func normalized(_ error: any Error) -> any Error {
        switch error {
        case is CancellationError:
            return error
        case let notificationError as NotificationError:
            return notificationError // unwrap이 던진 도메인 오류 그대로
        case let networkError as NetworkError:
            return NotificationError(networkError: networkError)
        default:
            return NotificationError.unknown
        }
    }

    init(networkError: NetworkError) {
        switch networkError {
        case .transport:
            self = .network
        case let .unacceptableStatusCode(statusCode, _):
            self = statusCode == 401
                ? .unauthorized
                : .server(message: "요청이 실패했어요. (HTTP \(statusCode))")
        case .invalidRequest, .nonHTTPResponse, .decoding:
            self = .unknown
        }
    }
}
