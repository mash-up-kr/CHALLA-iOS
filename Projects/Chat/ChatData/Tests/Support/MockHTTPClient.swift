import CHALLANetwork
import Foundation
import os

/// 호출을 캡처하고 지정한 응답을 돌려주는 `HTTPClient` 목.
/// (`PhotoData`·`UserData`의 같은 타입 복사본 — 공통화는 이슈 #51 소관)
///
/// `endpoint.baseURL`은 읽지 않는다 — `CHALLAAPIEnvironment`가 Info.plist를 요구해
/// 테스트 번들에서는 접근하는 순간 죽는다.
final class MockHTTPClient: HTTPClient {

    struct CapturedRequest: Sendable, Equatable {
        let path: String
        let method: HTTPMethod
        let usesBearerToken: Bool
        let body: Data?
        let queryItems: [URLQueryItem]?
    }

    let decoder = JSONDecoder()

    private let results: OSAllocatedUnfairLock<[Result<Response, any Error>]>
    private let captured = OSAllocatedUnfairLock<[CapturedRequest]>(initialState: [])

    init(results: [Result<Response, any Error>]) {
        self.results = OSAllocatedUnfairLock(initialState: results)
    }

    convenience init(result: Result<Response, any Error>) {
        self.init(results: [result])
    }

    var requests: [CapturedRequest] {
        captured.withLock { $0 }
    }

    func request(_ endpoint: some Endpoint) async throws -> Response {
        captured.withLock {
            $0.append(
                CapturedRequest(
                    path: endpoint.path,
                    method: endpoint.method,
                    usesBearerToken: Self.usesBearerToken(endpoint),
                    body: Self.body(of: endpoint.task),
                    queryItems: Self.queryItems(of: endpoint.task)
                )
            )
        }
        let next = results.withLock { $0.count > 1 ? $0.removeFirst() : $0.first }
        guard let next else {
            throw NetworkError.nonHTTPResponse
        }
        return try next.get()
    }

    private static func usesBearerToken(_ endpoint: some Endpoint) -> Bool {
        guard let authorizable = endpoint as? AccessTokenAuthorizable else { return true }
        if case .bearer = authorizable.authorizationType {
            return true
        }
        return false
    }

    private static func body(of task: HTTPTask) -> Data? {
        switch task {
        case let .requestJSONEncodable(value): return try? JSONEncoder().encode(value)
        case let .requestData(data): return data
        default: return nil
        }
    }

    private static func queryItems(of task: HTTPTask) -> [URLQueryItem]? {
        if case let .requestQueryItems(items) = task {
            return items
        }
        return nil
    }
}

extension MockHTTPClient {

    static func returning(statusCode: Int = 200, json: String) -> MockHTTPClient {
        MockHTTPClient(result: .success(Response(statusCode: statusCode, data: Data(json.utf8))))
    }

    static func failing(_ error: any Error) -> MockHTTPClient {
        MockHTTPClient(result: .failure(error))
    }
}
