import CHALLANetwork
import Foundation

/// 이미지 업로드 2단계. 발급만 우리 서버로 가고, 실제 전송은 스토리지로 직접 나간다.
/// `UserData`의 같은 타입을 복사한 것 (#51 머지 후 통합).
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
        // 발급 때 보낸 contentType과 정확히 같아야 한다 — 다르면 스토리지가 403을 낸다.
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
