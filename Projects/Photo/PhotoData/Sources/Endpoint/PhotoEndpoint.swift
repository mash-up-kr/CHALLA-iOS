import CHALLANetwork
import Foundation

enum PhotoEndpoint: Endpoint, AccessTokenAuthorizable {

    case complete(CompletePhotoRequestDTO)

    var baseURL: URL {
        CHALLAAPIEnvironment.baseURL
    }

    var path: String {
        "/api/v1/photos"
    }

    var method: HTTPMethod {
        .post
    }

    var task: HTTPTask {
        switch self {
        case let .complete(dto): return .requestJSONEncodable(dto)
        }
    }

    var authorizationType: AuthorizationType {
        .bearer
    }
}
