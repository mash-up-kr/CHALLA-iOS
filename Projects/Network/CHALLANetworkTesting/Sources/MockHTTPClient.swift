import CHALLANetwork
import Foundation
import os

/// 호출을 캡처하고 지정한 응답을 돌려주는 공용 `HTTPClient` 목.
///
/// Data 모듈 테스트가 공유한다 — Repository가 올바른 Endpoint를 골라 서버 계약대로 실었는지 검증한다.
/// `endpoint.baseURL`은 읽지 않는다 — `CHALLAAPIEnvironment`가 Info.plist를 요구해
/// 테스트 번들에서는 접근하는 순간 죽는다.
///
/// 요청을 기록하려면 참조 시맨틱이 필요해 final class + 락으로 구성한다
/// (iOS 17 타깃이라 `Mutex` 대신 `OSAllocatedUnfairLock`).
public final class MockHTTPClient: HTTPClient {

    /// 전송된 요청의 스냅샷 (라우팅·헤더·본문·쿼리 검증용).
    public struct CapturedRequest: Sendable, Equatable {
        public let path: String
        public let method: HTTPMethod
        public let headers: [String: String]
        public let usesBearerToken: Bool
        /// `.requestJSONEncodable`·`.requestData`로 실린 본문.
        public let body: Data?
        /// `.requestQueryItems`로 실린 쿼리 — 키 반복(배열 쿼리)까지 그대로 캡처한다.
        public let queryItems: [URLQueryItem]?
    }

    public let decoder = JSONDecoder()

    /// 호출 순서대로 소비하고, 다 쓰면 마지막 값을 반복한다 (생성→재조회처럼 왕복이 여러 번인 흐름용).
    private let results: OSAllocatedUnfairLock<[Result<Response, any Error>]>
    private let captured = OSAllocatedUnfairLock<[CapturedRequest]>(initialState: [])

    public init(results: [Result<Response, any Error>]) {
        self.results = OSAllocatedUnfairLock(initialState: results)
    }

    public convenience init(result: Result<Response, any Error>) {
        self.init(results: [result])
    }

    /// 전송된 요청들 (호출 순서대로).
    public var requests: [CapturedRequest] {
        captured.withLock { $0 }
    }

    public func request(_ endpoint: some Endpoint) async throws -> Response {
        captured.withLock {
            $0.append(
                CapturedRequest(
                    path: endpoint.path,
                    method: endpoint.method,
                    headers: endpoint.headers ?? [:],
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

    private static func queryItems(of task: HTTPTask) -> [URLQueryItem]? {
        if case let .requestQueryItems(items) = task {
            return items
        }
        return nil
    }
}

public extension MockHTTPClient {

    /// 지정 상태 코드 + JSON 본문을 돌려주는 목.
    static func returning(statusCode: Int = 200, json: String) -> MockHTTPClient {
        MockHTTPClient(result: .success(Response(statusCode: statusCode, data: Data(json.utf8))))
    }

    /// 전송 자체가 실패하는 목 (`NetworkError.transport` 등).
    static func failing(_ error: any Error) -> MockHTTPClient {
        MockHTTPClient(result: .failure(error))
    }

    /// 성공 응답 여러 개를 호출 순서대로 돌려주는 목 (왕복이 여러 번인 흐름용).
    static func succeeding(_ jsons: [String]) -> MockHTTPClient {
        MockHTTPClient(results: jsons.map { .success(Response(statusCode: 200, data: Data($0.utf8))) })
    }
}
