import CHALLANetwork
import ChatDomain
import Foundation

extension ChatError {

    /// 계층을 넘어온 오류를 도메인 오류로 정규화한다 (`PhotoError.normalized`와 같은 구조).
    /// 취소는 그대로 통과시킨다 — 호출자가 "실패 얼럿을 띄울 오류"와 구분해야 한다.
    static func normalized(_ error: any Error) -> any Error {
        switch error {
        case is CancellationError:
            return error
        case let chatError as ChatError:
            return chatError
        case let networkError as NetworkError:
            return ChatError(networkError: networkError)
        default:
            return ChatError.unknown
        }
    }

    init(networkError: NetworkError) {
        switch networkError {
        case .transport:
            self = .network
        case let .unacceptableStatusCode(statusCode, _):
            switch statusCode {
            case 401: self = .unauthorized
            default: self = .server(message: "요청이 실패했어요. (HTTP \(statusCode))")
            }
        case .invalidRequest, .nonHTTPResponse, .decoding:
            self = .unknown
        }
    }
}
