import Testing
import Foundation
import AuthDomain
import CHALLANetwork
@testable import AuthData

/// `NetworkError` → `AuthError` 매핑 전수 테이블 (`NetworkError` 5개 케이스 전부).
/// 케이스가 추가되면 매핑 switch가 컴파일 오류로 잡고, 여기에 기대값을 추가한다.
@Suite("AuthError+Mapping")
struct AuthErrorMappingTests {

    /// decoding 케이스의 underlying 자리 채움용 (매핑은 내용물을 보지 않는다).
    private struct AnyUnderlyingError: Error {}

    @Test("transport(전송 실패)는 .network로 매핑된다")
    func transportBecomesNetwork() {
        let networkError = NetworkError.transport(underlying: URLError(.notConnectedToInternet))

        #expect(AuthError(networkError: networkError) == .network)
    }

    @Test("상태 코드: 401만 .unauthorized, 그 외는 HTTP 코드를 담은 .server", arguments: zip(
        [401, 400, 404, 500],
        [
            AuthError.unauthorized,
            .server(message: "요청이 실패했어요. (HTTP 400)"),
            .server(message: "요청이 실패했어요. (HTTP 404)"),
            .server(message: "요청이 실패했어요. (HTTP 500)"),
        ]
    ))
    func statusCodeMapping(statusCode: Int, expected: AuthError) {
        let networkError = NetworkError.unacceptableStatusCode(
            statusCode: statusCode,
            response: Response(statusCode: statusCode, data: Data())
        )

        #expect(AuthError(networkError: networkError) == expected)
    }

    @Test("invalidRequest(요청 구성 실패)는 .unknown으로 매핑된다")
    func invalidRequestBecomesUnknown() {
        let networkError = NetworkError.invalidRequest(reason: "잘못된 URL")

        #expect(AuthError(networkError: networkError) == .unknown)
    }

    @Test("nonHTTPResponse는 .unknown으로 매핑된다")
    func nonHTTPResponseBecomesUnknown() {
        #expect(AuthError(networkError: .nonHTTPResponse) == .unknown)
    }

    @Test("decoding(본문 해석 실패)은 .unknown으로 매핑된다")
    func decodingBecomesUnknown() {
        let networkError = NetworkError.decoding(
            underlying: AnyUnderlyingError(),
            response: Response(statusCode: 200, data: Data("not-json".utf8))
        )

        #expect(AuthError(networkError: networkError) == .unknown)
    }
}
