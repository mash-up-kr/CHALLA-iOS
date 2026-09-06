import CHALLANetwork
import Foundation

/// 채팅 서버 API 선언. 리액션은 `type = "EMOJI"` 채팅이라 chat-controller에 속한다.
enum ChatEndpoint: Endpoint, AccessTokenAuthorizable {

    /// 사진에 이모지 리액션을 남긴다.
    case reaction(CreateReactionRequestDTO)
    /// 이모지 리액션 삭제.
    case deleteReaction(chatID: Int64)

    var baseURL: URL {
        CHALLAAPIEnvironment.baseURL
    }

    var path: String {
        switch self {
        case .reaction: return "/api/v1/chats/reaction"
        case let .deleteReaction(chatID): return "/api/v1/chats/reaction/\(chatID)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .reaction: return .post
        case .deleteReaction: return .delete
        }
    }

    var task: HTTPTask {
        switch self {
        case let .reaction(dto): return .requestJSONEncodable(dto)
        case .deleteReaction: return .requestPlain
        }
    }

    var authorizationType: AuthorizationType {
        .bearer
    }
}
