import Foundation

/// 쿼리 파라미터 별칭. 쿼리 값은 결국 문자열로 전송되므로 `[String: String]`이다.
/// 딕셔너리라 키 반복을 표현할 수 없다 — 배열 쿼리(반복 키)는 `HTTPTask.requestQueryItems`를 쓴다.
public typealias Parameters = [String: String]

/// 파라미터를 `URLRequest`에 실어넣는 방식.
public protocol ParameterEncoding: Sendable {
    func encode(_ request: URLRequest, with parameters: Parameters?) throws -> URLRequest
}

// MARK: - URLEncoding

/// 파라미터를 URL 쿼리스트링으로 인코딩한다.
public struct URLEncoding: ParameterEncoding {

    public init() {}

    public static var `default`: URLEncoding {
        URLEncoding()
    }

    public func encode(_ request: URLRequest, with parameters: Parameters?) throws -> URLRequest {
        var request = request
        guard let parameters, !parameters.isEmpty else { return request }

        guard let url = request.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidRequest(reason: "쿼리 인코딩 대상 URL이 유효하지 않습니다.")
        }
        let encoded = Self.query(parameters)
        let existing = components.percentEncodedQuery.map { $0 + "&" } ?? ""
        components.percentEncodedQuery = existing + encoded
        guard let newURL = components.url else {
            throw NetworkError.invalidRequest(reason: "쿼리 병합 후 URL 생성에 실패했습니다.")
        }
        request.url = newURL
        return request
    }

    /// 같은 키의 반복(배열 쿼리)을 보존해야 해서 딕셔너리 대신 `URLQueryItem` 배열을 받는다.
    /// 이스케이프·병합 규칙은 딕셔너리 encode와 동일하다.
    public func encode(_ request: URLRequest, with queryItems: [URLQueryItem]) throws -> URLRequest {
        var request = request
        guard !queryItems.isEmpty else { return request }

        guard let url = request.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidRequest(reason: "쿼리 인코딩 대상 URL이 유효하지 않습니다.")
        }
        let encoded = queryItems
            .map { "\(Self.escape($0.name))=\(Self.escape($0.value ?? ""))" }
            .joined(separator: "&")
        let existing = components.percentEncodedQuery.map { $0 + "&" } ?? ""
        components.percentEncodedQuery = existing + encoded
        guard let newURL = components.url else {
            throw NetworkError.invalidRequest(reason: "쿼리 병합 후 URL 생성에 실패했습니다.")
        }
        request.url = newURL
        return request
    }

    static func query(_ parameters: Parameters) -> String {
        parameters
            .sorted { $0.key < $1.key }
            .map { "\(escape($0.key))=\(escape($0.value))" }
            .joined(separator: "&")
    }

    /// RFC 3986에 따라 쿼리에서 이스케이프해야 하는 문자를 퍼센트 인코딩한다.
    static func escape(_ string: String) -> String {
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'()*+,;="
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: generalDelimitersToEncode + subDelimitersToEncode)
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
}
