import CHALLANetwork
import Foundation

/// 촬영 관련 서버 API 선언. LUT 파일 조회는 서버가 아니라 스토리지 공개 URL로 나간다.
enum ShootEndpoint: Endpoint, AccessTokenAuthorizable {

    case cameraFilters
    /// 필터의 .cube 파일 다운로드. 공개 URL이라 인증이 필요 없다.
    case cubeFile(URL)

    var baseURL: URL {
        switch self {
        case .cameraFilters: return CHALLAAPIEnvironment.baseURL
        case let .cubeFile(url): return url
        }
    }

    var path: String {
        switch self {
        case .cameraFilters: return "/api/v1/shoots/camera-filters"
        case .cubeFile: return "" // 공개 URL이 경로를 모두 담고 있다
        }
    }

    var method: HTTPMethod {
        .get
    }

    var task: HTTPTask {
        .requestPlain
    }

    var authorizationType: AuthorizationType {
        switch self {
        case .cameraFilters: return .bearer
        case .cubeFile: return .none // 스토리지 공개 URL — 서버 토큰을 보낼 이유가 없다
        }
    }
}
