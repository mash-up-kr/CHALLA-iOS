import Foundation

/// `URLSession` 기반 `HTTPClient` 구현. Moya의 `MoyaProvider`에 대응한다.
///
/// 파이프라인: Endpoint → URLRequest 변환 → 인터셉터 `adapt` 연쇄 →
/// `willSend` → `URLSession` 전송 → `Response` 조립 → `didReceive`.
public final class DefaultHTTPClient: HTTPClient {

    private let session: URLSession
    private let interceptors: [any Interceptor]

    /// - Parameters:
    ///   - session: 전송에 쓸 `URLSession` (기본 `.shared`).
    ///   - interceptors: 등록 순서대로 `adapt`가 연쇄 적용된다. 예: `[AuthInterceptor(...), LoggingInterceptor()]`.
    public init(
        session: URLSession = .shared,
        interceptors: [any Interceptor] = []
    ) {
        self.session = session
        self.interceptors = interceptors
    }

    public func request(_ endpoint: some Endpoint) async throws -> Response {
        // 1. Endpoint → URLRequest
        var urlRequest: URLRequest
        do {
            urlRequest = try endpoint.asURLRequest()
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.invalidRequest(reason: error.localizedDescription)
        }

        // 2. 인터셉터 adapt (헤더 주입 등) — 등록 순서대로 연쇄
        for interceptor in interceptors {
            urlRequest = try await interceptor.adapt(urlRequest, for: endpoint)
        }

        // 3. willSend
        for interceptor in interceptors {
            interceptor.willSend(urlRequest, endpoint: endpoint)
        }

        // 4. 전송 + Response 조립
        do {
            let (data, urlResponse) = try await session.data(for: urlRequest)

            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw NetworkError.nonHTTPResponse
            }

            let response = Response(
                statusCode: httpResponse.statusCode,
                data: data,
                request: urlRequest,
                headers: Self.headers(from: httpResponse)
            )
            notifyDidReceive(.success(response), endpoint: endpoint)
            return response

        } catch let error as NetworkError {
            notifyDidReceive(.failure(error), endpoint: endpoint)
            throw error
        } catch {
            let networkError = NetworkError.transport(underlying: error)
            notifyDidReceive(.failure(networkError), endpoint: endpoint)
            throw networkError
        }
    }

    private func notifyDidReceive(_ result: Result<Response, NetworkError>, endpoint: some Endpoint) {
        for interceptor in interceptors {
            interceptor.didReceive(result, endpoint: endpoint)
        }
    }

    /// `HTTPURLResponse`(비-Sendable)의 헤더를 `[String: String]`로 추출한다.
    private static func headers(from response: HTTPURLResponse) -> [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key] = value
            }
        }
        return headers
    }
}
