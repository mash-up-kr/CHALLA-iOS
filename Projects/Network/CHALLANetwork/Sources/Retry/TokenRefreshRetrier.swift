import Foundation

/// 401을 만나면 액세스 토큰을 갱신하고 요청을 한 번 다시 보낸다.
///
/// 갱신이 실패하면 재시도하지 않는다 — 401 응답이 그대로 Data 레이어로 올라가
/// 각 도메인 오류(`AuthError.unauthorized` 등)로 정규화된다.
public struct TokenRefreshRetrier: Retrier {

    private let refresher: any TokenRefreshing

    public init(refresher: any TokenRefreshing) {
        self.refresher = refresher
    }

    public func shouldRetry(
        _ result: Result<Response, NetworkError>,
        endpoint: any Endpoint,
        attempt: Int
    ) async -> Bool {
        guard attempt == 0 else { return false } // 갱신한 토큰으로도 401이면 갱신으로 풀 문제가 아니다
        guard case let .success(response) = result, response.statusCode == 401 else { return false }

        // 토큰을 싣지 않는 엔드포인트(로그인·갱신)의 401은 자격 증명 자체가 거절된 것이라 갱신해도 달라지지 않는다.
        let authorizationType = (endpoint as? AccessTokenAuthorizable)?.authorizationType ?? .bearer
        guard authorizationType == .bearer else { return false }

        return await refresher.refreshToken(replacing: Self.bearerToken(of: response.request))
    }

    private static func bearerToken(of request: URLRequest?) -> String? {
        guard let header = request?.value(forHTTPHeaderField: "Authorization") else { return nil }

        let prefix = "Bearer "
        return header.hasPrefix(prefix) ? String(header.dropFirst(prefix.count)) : header
    }
}
