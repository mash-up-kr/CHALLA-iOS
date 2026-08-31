import CHALLANetwork
import Foundation

/// 앱 메타 API 선언. 현재는 버전 체크 하나다.
enum AppEndpoint: Endpoint, AccessTokenAuthorizable {

    case version(currentVersion: String)

    var baseURL: URL {
        CHALLAAPIEnvironment.baseURL
    }

    var path: String {
        "/api/v1/app/version"
    }

    var method: HTTPMethod {
        .get
    }

    var task: HTTPTask {
        switch self {
        case let .version(currentVersion):
            return .requestQueryItems([
                URLQueryItem(name: "os", value: "IOS"), // 서버 enum: ANDROID | IOS
                URLQueryItem(name: "version", value: currentVersion)
            ])
        }
    }

    var authorizationType: AuthorizationType {
        .none // 로그인 전(스플래시)에 부른다 — 토큰이 없어도 응답해야 한다
    }
}
