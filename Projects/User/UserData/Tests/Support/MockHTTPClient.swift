import CHALLANetwork
import Foundation
import os

/// 호출을 캡처하고 지정한 응답을 돌려주는 `HTTPClient` 목.
///
/// `endpoint.baseURL`은 읽지 않는다 — `CHALLAAPIEnvironment`가 Info.plist를 요구해
/// 테스트 번들에서는 접근하는 순간 죽는다. URL 규약은 `UploadEndpointTests`가 따로 고정한다.
final class MockHTTPClient: HTTPClient {

    struct CapturedRequest: Sendable, Equatable {
        let path: String
        let method: HTTPMethod
        let headers: [String: String]
        let usesBearerToken: Bool
        /// `.requestJSONEncodable`·`.requestData`로 실린 본문 — 서버 계약대로 실렸는지 검증한다.
        let body: Data?
    }

    let decoder = JSONDecoder()

    /// 호출 순서대로 소비하고, 다 쓰면 마지막 값을 반복한다 (업로드처럼 왕복이 여러 번인 흐름용).
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
                    headers: endpoint.headers ?? [:],
                    usesBearerToken: Self.usesBearerToken(endpoint),
                    body: Self.body(of: endpoint.task)
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
        // 인터셉터와 같은 규칙 — 미채택 엔드포인트는 bearer로 간주한다.
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
}

extension MockHTTPClient {

    static func returning(statusCode: Int = 200, json: String) -> MockHTTPClient {
        MockHTTPClient(result: .success(Response(statusCode: statusCode, data: Data(json.utf8))))
    }

    static func failing(_ error: any Error) -> MockHTTPClient {
        MockHTTPClient(result: .failure(error))
    }

    static func succeeding(_ jsons: [String]) -> MockHTTPClient {
        MockHTTPClient(results: jsons.map { .success(Response(statusCode: 200, data: Data($0.utf8))) })
    }
}
