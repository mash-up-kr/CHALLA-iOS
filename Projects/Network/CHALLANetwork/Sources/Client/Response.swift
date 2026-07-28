import Foundation

/// 서버 응답 한 건. Moya의 `Response`에 대응한다.
/// 상태 코드 필터링(`filter...`)과 디코딩(`map`) 헬퍼를 체이닝해서 쓴다.
///
/// 저장 프로퍼티가 모두 값 타입이라 `@unchecked` 없이 `Sendable`이다.
/// (헤더는 비-Sendable `HTTPURLResponse` 대신 `[String: String]`로 노출한다.)
public struct Response: Sendable {

    /// HTTP 상태 코드.
    public let statusCode: Int
    /// 응답 본문 원본.
    public let data: Data
    /// 이 응답을 만든 요청 (디버깅·로깅용).
    public let request: URLRequest?
    /// 응답 헤더.
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

    /// 상태 코드가 주어진 범위 안이면 그대로 반환하고, 아니면 오류를 던진다.
    func filter(statusCodes: Range<Int>) throws -> Response {
        guard statusCodes.contains(statusCode) else {
            throw NetworkError.unacceptableStatusCode(statusCode: statusCode, response: self)
        }
        return self
    }

    /// 2xx(성공) 상태 코드만 통과시킨다.
    func filterSuccessfulStatusCodes() throws -> Response {
        try filter(statusCodes: 200 ..< 300)
    }
}

// MARK: - 디코딩

public extension Response {

    /// 응답 본문을 `Decodable` 모델로 디코딩한다.
    func map<D: Decodable>(_ type: D.Type, using decoder: JSONDecoder = JSONDecoder()) throws -> D {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NetworkError.decoding(underlying: error, response: self)
        }
    }
}
