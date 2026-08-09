import CHALLANetwork
import Foundation
import UserDomain

extension UserError {

    /// 계층을 넘어온 오류를 도메인 오류로 정규화한다.
    /// 취소는 그대로 통과시킨다 — 호출자가 "실패 토스트를 띄울 오류"와 구분해야 한다.
    static func normalized(_ error: any Error) -> any Error {
        switch error {
        case is CancellationError:
            return error
        case let userError as UserError:
            return userError // unwrap이 던진 도메인 오류 그대로
        case let networkError as NetworkError:
            return UserError(networkError: networkError)
        default:
            return UserError.unknown
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
