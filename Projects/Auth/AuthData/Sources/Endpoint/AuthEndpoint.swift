import Foundation
import CHALLANetwork

/// 인증 서버 API 선언 (aggregate 단위 1개 enum — `Endpoint` 규약 참조).
///
/// `AccessTokenAuthorizable`로 요청별 토큰 부착 여부를 스스로 선언한다 —
/// login/refresh는 공개 API(토큰 없음), logout만 Bearer.
enum AuthEndpoint: Endpoint, AccessTokenAuthorizable {

    case login(LoginRequestDTO)
    case refresh(RefreshRequestDTO)
    case logout(LogoutRequestDTO)

    var baseURL: URL { CHALLAAPIEnvironment.baseURL }

    var path: String {
        switch self {
        case .login:   return "/api/v1/auth/login"
        case .refresh: return "/api/v1/auth/refresh"
        case .logout:  return "/api/v1/auth/logout"
        }
    }

    var method: HTTPMethod { .post }   // 셋 다 POST

    var task: HTTPTask {
        switch self {
        case .login(let dto):   return .requestJSONEncodable(dto)
        case .refresh(let dto): return .requestJSONEncodable(dto)
        case .logout(let dto):  return .requestJSONEncodable(dto)
        }
    }

    var authorizationType: AuthorizationType {
        switch self {
        case .login, .refresh: return .none
        case .logout:          return .bearer
        }
    }
}
