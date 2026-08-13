import CHALLANetwork
import Foundation

/// 알림 서버 API 선언 (aggregate 단위 1개 enum — `Endpoint` 규약 참조).
enum NotificationEndpoint: Endpoint, AccessTokenAuthorizable {

    case registerToken(DeviceTokenRequestDTO)
    case deleteToken(DeviceTokenRequestDTO)
    case sendTest(TestPushRequestDTO)

    var baseURL: URL {
        CHALLAAPIEnvironment.baseURL
    }

    var path: String {
        switch self {
        case .registerToken, .deleteToken: return "/api/v1/notifications/tokens"
        case .sendTest: return "/api/v1/notifications/test"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .registerToken, .sendTest: return .post
        case .deleteToken: return .delete
        }
    }

    /// 해제도 본문으로 토큰을 받는다 — query 파라미터가 아니다 (서버 스펙).
    var task: HTTPTask {
        switch self {
        case let .registerToken(dto), let .deleteToken(dto): return .requestJSONEncodable(dto)
        case let .sendTest(dto): return .requestJSONEncodable(dto)
        }
    }

    var authorizationType: AuthorizationType {
        .bearer
    } // 셋 다 내 계정 기준으로 동작한다
}
