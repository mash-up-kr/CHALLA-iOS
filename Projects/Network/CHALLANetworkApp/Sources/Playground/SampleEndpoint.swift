import Foundation
import CHALLANetwork

/// JSONPlaceholder(https://jsonplaceholder.typicode.com)를 대상으로 한 데모 엔드포인트.
/// 실제 Data 레이어가 `Endpoint`를 어떻게 채택하는지 보여주는 예시이기도 하다.
enum SampleEndpoint: Endpoint {
    /// GET 목록 — `requestPlain`
    case posts
    /// GET 단건
    case post(id: Int)
    /// GET 쿼리 파라미터 — `URLEncoding`
    case postsByUser(userId: Int)
    /// POST JSON 본문 — `requestJSONEncodable`
    case createPost(title: String, body: String, userId: Int)
    /// 존재하지 않는 경로 — 404 처리 데모
    case notFound

    var baseURL: URL { URL(string: "https://jsonplaceholder.typicode.com")! }

    var path: String {
        switch self {
        case .posts, .postsByUser, .createPost:
            return "/posts"
        case .post(let id):
            return "/posts/\(id)"
        case .notFound:
            return "/this-path-does-not-exist"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .posts, .post, .postsByUser, .notFound:
            return .get
        case .createPost:
            return .post
        }
    }

    var task: HTTPTask {
        switch self {
        case .posts, .post, .notFound:
            return .requestPlain
        case .postsByUser(let userId):
            return .requestParameters(parameters: ["userId": String(userId)], encoding: URLEncoding.default)
        case .createPost(let title, let body, let userId):
            return .requestJSONEncodable(CreatePostRequest(title: title, body: body, userId: userId))
        }
    }
}

/// POST 본문 모델.
private struct CreatePostRequest: Encodable {
    let title: String
    let body: String
    let userId: Int
}
