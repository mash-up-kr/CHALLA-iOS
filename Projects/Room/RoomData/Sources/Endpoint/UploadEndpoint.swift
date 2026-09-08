import CHALLANetwork
import Foundation

/// UserData의 UploadEndpoint와 중복 — 공통화는 #51 소관
enum UploadEndpoint: Endpoint, AccessTokenAuthorizable {

    case issue(IssueUploadURLRequestDTO)
    case put(url: URL, data: Data, contentType: String)

    var baseURL: URL {
        switch self {
        case .issue: return CHALLAAPIEnvironment.baseURL
        case let .put(url, _, _): return url
        }
    }

    var path: String {
        switch self {
        case .issue: return "/api/v1/uploads"
        case .put: return "" // 서명 URL이 경로·쿼리를 모두 담고 있다
        }
    }

    var method: HTTPMethod {
        switch self {
        case .issue: return .post
        case .put: return .put
        }
    }

    var task: HTTPTask {
        switch self {
        case let .issue(dto): return .requestJSONEncodable(dto)
        case let .put(_, data, _): return .requestData(data)
        }
    }

    var headers: [String: String]? {
        switch self {
        case .issue: return nil
        case let .put(_, _, contentType): return ["Content-Type": contentType]
        }
    }

    var authorizationType: AuthorizationType {
        switch self {
        case .issue: return .bearer
        case .put: return .none // Authorization을 붙이면 서명이 깨져 403이 난다
        }
    }
}
