import Foundation

/// 401을 받은 요청을 다시 보내기 전에 액세스 토큰을 갱신하는 접점. 구현은 `AuthData`.
public protocol TokenRefreshing: Sendable {

    /// - Parameter staleAccessToken: 401을 받은 요청이 실어 보낸 액세스 토큰.
    ///   그 사이 다른 요청이 이미 갱신을 끝냈는지 판단하는 데 쓴다.
    /// - Returns: 새 토큰으로 재시도할 수 있으면 `true`. 재로그인이 필요하거나 갱신에 실패하면 `false`.
    func refreshToken(replacing staleAccessToken: String?) async -> Bool
}
