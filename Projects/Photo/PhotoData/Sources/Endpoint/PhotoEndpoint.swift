import CHALLANetwork
import Foundation

enum PhotoEndpoint: Endpoint, AccessTokenAuthorizable {

    /// 방의 인화된 사진 목록 (페이지네이션).
    case list(roomID: Int64, page: Int, size: Int)
    /// 리액션을 포함한 사진 상세 조회. `roomId`는 필수 파라미터다.
    case detail(roomID: Int64, photoID: Int64)
    /// 스토리지에 올린 사진을 방에 반영해 달라는 완료 통보.
    case complete(CompletePhotoRequestDTO)

    var baseURL: URL {
        CHALLAAPIEnvironment.baseURL
    }

    var path: String {
        switch self {
        case .list, .complete: return "/api/v1/photos"
        case let .detail(_, photoID): return "/api/v1/photos/\(photoID)"
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
        case let .detail(roomID, _):
            return .requestQueryItems([URLQueryItem(name: "roomId", value: String(roomID))])
        case let .complete(dto):
            return .requestJSONEncodable(dto)
        }
    }

    var authorizationType: AuthorizationType {
        .bearer
    }
}
