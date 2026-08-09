import CHALLANetwork
import Foundation

/// 유저 서버 API 선언 (aggregate 단위 1개 enum — `Endpoint` 규약 참조).
enum UserEndpoint: Endpoint, AccessTokenAuthorizable {

    case me
    case updateMe(UpdateProfileRequestDTO)
    case deleteMe

    var baseURL: URL {
        CHALLAAPIEnvironment.baseURL
    }

    var path: String {
        "/api/v1/users/me"
    } // 셋 다 같은 리소스, 메서드로만 갈린다

    var method: HTTPMethod {
        switch self {
        case .me: return .get
        case .updateMe: return .put
        case .deleteMe: return .delete
        }
    }

    var task: HTTPTask {
        switch self {
        case .me, .deleteMe: return .requestPlain
        case let .updateMe(dto): return .requestJSONEncodable(dto)
        }
    }

    var authorizationType: AuthorizationType {
        .bearer
    }
}
