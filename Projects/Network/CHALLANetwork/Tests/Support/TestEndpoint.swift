import Foundation
import CHALLANetwork

/// 테스트에서 각 속성을 자유롭게 바꿔가며 쓰는 범용 Endpoint.
struct TestEndpoint: Endpoint {
    var baseURL = URL(string: "https://api.example.com")!
    var path = "/v1/resource"
    var method: HTTPMethod = .get
    var task: HTTPTask = .requestPlain
    var headers: [String: String]?
}

/// `AccessTokenAuthorizable` 분기(.none/.bearer/.custom)를 검증하기 위한 Endpoint.
struct AuthTestEndpoint: Endpoint, AccessTokenAuthorizable {
    var authorizationType: AuthorizationType
    var baseURL = URL(string: "https://api.example.com")!
    var path = "/secure"
    var method: HTTPMethod = .get
    var task: HTTPTask = .requestPlain
}
