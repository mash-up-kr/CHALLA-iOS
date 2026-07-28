import Foundation

/// `TokenProvider`가 준 토큰을 `Authorization: Bearer` 헤더에 실어주는 인터셉터.
///
/// 엔드포인트가 `AccessTokenAuthorizable`를 채택하면 그 선언(`.none`/`.bearer`)을 따르고,
/// 채택하지 않으면 기본값 `.bearer`로 동작한다. 토큰이 없으면(비로그인) 헤더를 붙이지 않는다.
public struct AuthInterceptor: Interceptor {

    private let tokenProvider: any TokenProvider

    public init(tokenProvider: any TokenProvider) {
        self.tokenProvider = tokenProvider
    }

    public func adapt(_ request: URLRequest, for endpoint: any Endpoint) async throws -> URLRequest {
        let authorizationType = (endpoint as? AccessTokenAuthorizable)?.authorizationType ?? .bearer
        guard authorizationType == .bearer else { return request }

        guard let token = await tokenProvider.accessToken() else { return request }

        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
