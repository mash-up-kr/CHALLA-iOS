import Foundation

/// `URLSession` 기반 `HTTPClient` 구현.
///
/// 파이프라인: Endpoint → URLRequest 변환 → 인터셉터 `adapt` 연쇄 →
/// `willSend` → `URLSession` 전송 → `Response` 조립 → `didReceive`.
/// `retrier`가 재시도를 지시하면 `adapt`부터 다시 돈다.
public final class DefaultHTTPClient: HTTPClient {

    private let session: URLSession
    private let interceptors: [any Interceptor]
    private let retrier: (any Retrier)?
    private let encoder = JSONEncoder()
    public let decoder = JSONDecoder()

    /// - Parameters:
    ///   - session: 전송에 쓸 `URLSession` (기본 `.shared`).
    ///   - interceptors: 등록 순서대로 `adapt`가 연쇄 적용된다. 예: `[AuthInterceptor(...), LoggingInterceptor()]`.
    ///   - retrier: 실패한 요청의 재시도 판정. 없으면 응답을 그대로 돌려준다.
    public init(
        session: URLSession = .shared,
        interceptors: [any Interceptor] = [],
        retrier: (any Retrier)? = nil
    ) {
        self.session = session
        self.interceptors = interceptors
        self.retrier = retrier
    }

    public func request(_ endpoint: some Endpoint) async throws -> Response {
        let urlRequest = try makeURLRequest(endpoint)

        var attempt = 0
        while true {
            let result = try await send(urlRequest, endpoint: endpoint)

            guard
                let retrier,
                await retrier.shouldRetry(result, endpoint: endpoint, attempt: attempt)
            else {
                return try result.get()
            }
            attempt += 1
        }
    }

    /// 요청 조립 실패는 재시도해도 결과가 같으므로 루프 밖에서 한 번만 수행한다.
    private func makeURLRequest(_ endpoint: some Endpoint) throws -> URLRequest {
        do {
            return try endpoint.asURLRequest(encoder: encoder)
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.invalidRequest(reason: error.localizedDescription)
        }
    }

    /// 취소만 던지고, 나머지 전송 결과는 `Result`로 돌려 재시도 판정에 넘긴다.
    private func send(
        _ urlRequest: URLRequest,
        endpoint: some Endpoint
    ) async throws -> Result<Response, NetworkError> {
        var urlRequest = urlRequest
        for interceptor in interceptors {
            urlRequest = try await interceptor.adapt(urlRequest, for: endpoint)
        }

        for interceptor in interceptors {
            interceptor.willSend(urlRequest, endpoint: endpoint)
        }

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
            return .success(response)

        } catch let error as NetworkError {
            notifyDidReceive(.failure(error), endpoint: endpoint)
            return .failure(error)
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            let networkError = NetworkError.transport(underlying: error)
            notifyDidReceive(.failure(networkError), endpoint: endpoint)
            return .failure(networkError)
        }
    }

    private func notifyDidReceive(_ result: Result<Response, NetworkError>, endpoint: some Endpoint) {
        for interceptor in interceptors {
            interceptor.didReceive(result, endpoint: endpoint)
        }
    }

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
