import CHALLANetwork
import Foundation
import RoomDomain

extension RoomError {

    /// 계층을 넘어온 오류를 도메인 오류로 정규화한다 (`UserError.normalized`와 같은 구조).
    /// 취소는 그대로 통과시킨다 — 호출자가 "실패 얼럿을 띄울 오류"와 구분해야 한다.
    static func normalized(_ error: any Error) -> any Error {
        switch error {
        case is CancellationError:
            return error
        case let roomError as RoomError:
            return roomError // unwrap·매핑이 던진 도메인 오류 그대로
        case let networkError as NetworkError:
            return RoomError(networkError: networkError)
        default:
            return RoomError.unknown
        }
    }

    /// 네트워크 계층의 실패를 방 도메인의 실패로 바꾸는 번역표.
    /// TODO: 백엔드 확인 — 스웨거에 에러 응답 정의가 없어 404/409 매핑은 잠정이다.
    ///       (없는 초대 코드·정원 초과의 실제 상태 코드와 에러 바디 형식 확인 후 확정)
    init(networkError: NetworkError) {
        switch networkError {
        case .transport:
            self = .network
        case let .unacceptableStatusCode(statusCode, _):
            switch statusCode {
            case 401: self = .unauthorized
            case 404: self = .roomNotFound
            case 409: self = .roomFull
            default: self = .server(message: "요청이 실패했어요. (HTTP \(statusCode))")
            }
        case .invalidRequest, .nonHTTPResponse, .decoding:
            self = .unknown
        }
    }
}
