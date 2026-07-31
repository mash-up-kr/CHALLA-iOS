import Foundation

/// 서버 응답 한 건. 상태 코드 필터링(`filter...`)과 디코딩(`map`) 헬퍼를 체이닝해서 쓴다.
///
/// 헤더는 비-Sendable `HTTPURLResponse` 대신 `[String: String]`로 노출한다.
public struct Response: Sendable {

    public let statusCode: Int
    public let data: Data
    /// 이 응답을 만든 요청 (디버깅·로깅용).
    public let request: URLRequest?
    public let headers: [String: String]

    public init(
        statusCode: Int,
        data: Data,
        request: URLRequest? = nil,
        headers: [String: String] = [:]
    ) {
        self.statusCode = statusCode
        self.data = data
        self.request = request
        self.headers = headers
    }
}

// MARK: - 상태 코드 필터

public extension Response {

    func filter(statusCodes: Range<Int>) throws -> Response {
        guard statusCodes.contains(statusCode) else {
            throw NetworkError.unacceptableStatusCode(statusCode: statusCode, response: self)
        }
        return self
    }

    func filterSuccessfulStatusCodes() throws -> Response {
        try filter(statusCodes: 200 ..< 300)
    }
}

// MARK: - 디코딩

public extension Response {

    /// 응답 본문을 `Decodable` 모델로 디코딩한다.
    func map<D: Decodable>(_ type: D.Type, using decoder: JSONDecoder) throws -> D {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NetworkError.decoding(underlying: error, response: self)
        }
    }
}
