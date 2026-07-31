@testable import CHALLANetwork
import Foundation
import Testing

@Suite("AuthInterceptor")
struct AuthInterceptorTests {

    private let request = URLRequest(url: URL(string: "https://a.com")!)

    @Test("토큰이 있으면 Bearer 헤더를 붙인다 (기본 정책)")
    func bearerInjected() async throws {
        let interceptor = AuthInterceptor(tokenProvider: FakeTokenProvider(token: "abc"))
        let adapted = try await interceptor.adapt(request, for: TestEndpoint())
        #expect(adapted.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
    }

    @Test("토큰이 없으면 인증 헤더를 붙이지 않는다")
    func noTokenNoHeader() async throws {
        let interceptor = AuthInterceptor(tokenProvider: FakeTokenProvider(token: nil))
        let adapted = try await interceptor.adapt(request, for: TestEndpoint())
        #expect(adapted.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("authorizationType이 .none이면 토큰이 있어도 건너뛴다")
    func authTypeNone() async throws {
        let interceptor = AuthInterceptor(tokenProvider: FakeTokenProvider(token: "abc"))
        let endpoint = AuthTestEndpoint(authorizationType: .none)
        let adapted = try await interceptor.adapt(request, for: endpoint)
        #expect(adapted.value(forHTTPHeaderField: "Authorization") == nil)
    }
}
