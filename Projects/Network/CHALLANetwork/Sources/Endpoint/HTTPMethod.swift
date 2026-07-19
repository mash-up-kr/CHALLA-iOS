import Foundation

/// HTTP 메서드. Moya의 `Moya.Method`(Alamofire `HTTPMethod`)에 대응한다.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
