import CHALLANetwork
import Foundation

/// 채팅 서버 API. (PhotoData에도 리액션용 `ChatEndpoint`가 있으나 다른 모듈·internal이라 충돌하지 않는다.)
enum ChatEndpoint: Endpoint, AccessTokenAuthorizable {

    /// 메시지 작성.
    case send(SendChatRequestDTO)
    /// 방의 채팅 목록 (페이지네이션).
    case list(roomID: Int64, page: Int, size: Int)

    var baseURL: URL {
        CHALLAAPIEnvironment.baseURL
    }

    var path: String {
        switch self {
        case .send: return "/api/v1/chats"
        case let .list(roomID, _, _): return "/api/v1/chats/\(roomID)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .send: return .post
        case .list: return .get
        }
    }

    var task: HTTPTask {
        switch self {
        case let .send(dto):
            return .requestJSONEncodable(dto)
        case let .list(_, page, size):
            return .requestQueryItems([
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ])
        }
    }

    var authorizationType: AuthorizationType {
        .bearer
    }
}
