import Foundation

/// 서버가 발급한 토큰 쌍.
///
/// 저장(`TokenStore`)과 갱신(`AuthRepository.refresh`)의 단위다.
public struct AuthToken: Sendable, Equatable {

    public let accessToken: String
    public let refreshToken: String

    public init(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}
