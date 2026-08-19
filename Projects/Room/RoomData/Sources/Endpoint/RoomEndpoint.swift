import CHALLANetwork
import Foundation

/// 방 서버 API 선언. UserEndpoint처럼 도메인 하나(방)의 API를 enum 하나에 case로 모은다.
enum RoomEndpoint: Endpoint, AccessTokenAuthorizable {

    /// 상태 필터는 최소 1개 필수 (생략하면 서버가 400을 낸다). 전체 조회는 세 상태를 다 넘긴다.
    case rooms(statuses: [RoomStatusDTO])
    case shootable
    case create(CreateRoomRequestDTO)
    case join(JoinRoomRequestDTO)

    var baseURL: URL {
        CHALLAAPIEnvironment.baseURL
    }

    var path: String {
        switch self {
        case .rooms, .create: return "/api/v1/rooms" // 같은 경로, GET/POST로 갈린다
        case .shootable: return "/api/v1/rooms/shootable"
        case .join: return "/api/v1/rooms/join"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .rooms, .shootable: return .get
        case .create, .join: return .post
        }
    }

    var task: HTTPTask {
        switch self {
        case let .rooms(statuses):
            // 같은 키를 반복하는 배열 쿼리 (?status=A&status=B) — Spring의 List 바인딩 관례.
            return .requestQueryItems(statuses.map { URLQueryItem(name: "status", value: $0.rawValue) })
        case .shootable:
            return .requestPlain
        case let .create(dto):
            return .requestJSONEncodable(dto)
        case let .join(dto):
            return .requestJSONEncodable(dto)
        }
    }

    var authorizationType: AuthorizationType {
        .bearer // 전부 로그인 필요 — AuthInterceptor가 토큰을 붙인다
    }
}
