import Foundation
import os
import CHALLANetwork

/// 지정한 결과 하나를 돌려주고, 전달받은 엔드포인트의 경로·메서드를 기록하는 `HTTPClient` 목.
///
/// 요청을 기록하려면 참조 시맨틱이 필요해 final class + 락으로 구성한다
/// (iOS 17 타깃이라 `Mutex` 대신 `OSAllocatedUnfairLock`).
final class MockHTTPClient: HTTPClient {

    /// 전송된 요청의 경로·메서드 (라우팅 검증용 — Repository가 올바른 Endpoint를 골랐는지 확인).
    struct CapturedRequest: Sendable, Equatable {
        let path: String
        let method: HTTPMethod
    }

    private let result: Result<Response, any Error>
    private let captured = OSAllocatedUnfairLock<[CapturedRequest]>(initialState: [])

    init(result: Result<Response, any Error>) {
        self.result = result
    }

    /// 전송된 요청들 (호출 순서대로).
    var requests: [CapturedRequest] { captured.withLock { $0 } }

    func request(_ endpoint: some Endpoint) async throws -> Response {
        captured.withLock {
            $0.append(CapturedRequest(path: endpoint.path, method: endpoint.method))
        }
        return try result.get()
    }
}

extension MockHTTPClient {

    /// 지정 상태 코드 + JSON 본문을 돌려주는 목.
    static func returning(statusCode: Int = 200, json: String) -> MockHTTPClient {
        MockHTTPClient(result: .success(Response(statusCode: statusCode, data: Data(json.utf8))))
    }

    /// 전송 자체가 실패하는 목 (`NetworkError.transport` 등).
    static func failing(_ error: any Error) -> MockHTTPClient {
        MockHTTPClient(result: .failure(error))
    }
}
