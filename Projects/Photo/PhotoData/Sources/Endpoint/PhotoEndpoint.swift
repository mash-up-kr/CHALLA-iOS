import CHALLANetwork
import Foundation

enum PhotoEndpoint: Endpoint, AccessTokenAuthorizable {

    /// 방의 인화된 사진 목록 (페이지네이션).
    case list(roomID: Int64, page: Int, size: Int)
    /// 사진 한 장의 상세 — 리액션(chats)을 받는다.
    case detail(photoID: Int64)
    /// 스토리지에 올린 사진을 방에 반영해 달라는 완료 통보.
    case complete(CompletePhotoRequestDTO)

    var baseURL: URL {
        CHALLAAPIEnvironment.baseURL
    }

    var path: String {
        switch self {
        case .list, .complete: return "/api/v1/photos"
        case let .detail(photoID): return "/api/v1/photos/\(photoID)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .detail: return .get
        case .complete: return .post
        }
    }

    var task: HTTPTask {
        switch self {
        case let .list(roomID, page, size):
            return .requestQueryItems([
                URLQueryItem(name: "roomId", value: String(roomID)),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ])
        case .detail:
            return .requestPlain
        case let .complete(dto):
            return .requestJSONEncodable(dto)
        }
    }

    var authorizationType: AuthorizationType {
        .bearer
    }
}
