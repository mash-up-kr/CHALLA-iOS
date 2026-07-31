import AuthDomain
import CHALLANetwork
import Foundation
import Keychain

/// 하나의 Keychain 위에서 Domain의 `TokenStore`와 Network의 `TokenProvider`를 동시에 만족시킨다.
///
/// 두 프로토콜의 접점이 이 타입 하나뿐이라 저장 위치(Keychain)가 밖으로 새지 않는다.
public final class KeychainTokenStore: TokenStore, TokenProvider {

    // MARK: - Properties

    private let keychain: any Keychain

    /// 토큰 쌍을 담는 단일 항목의 키.
    ///
    /// 키체인에는 트랜잭션이 없어 access·refresh를 두 키로 나누면
    /// 앞의 저장만 성공했을 때 새 access + 옛 refresh 불일치가 남는다.
    private static let tokenKey = "challa.auth.token"

    /// 키체인에 직렬화되는 형태. Domain 엔티티(`AuthToken`)에 저장 포맷을 떠넘기지 않으려고 따로 둔다.
    private struct StoredToken: Codable {
        let accessToken: String
        let refreshToken: String
    }

    // MARK: - Initialization

    public init(keychain: any Keychain) {
        self.keychain = keychain
    }

    // MARK: - TokenStore (Domain)

    public func save(_ token: AuthToken) throws {
        let stored = StoredToken(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken
        )
        try keychain.save(JSONEncoder().encode(stored), for: Self.tokenKey)
    }

    public func loadAccessToken() -> String? {
        loadStoredToken()?.accessToken
    }

    public func loadRefreshToken() -> String? {
        loadStoredToken()?.refreshToken
    }

    public func clear() throws {
        try keychain.delete(for: Self.tokenKey)
    }

    // MARK: - Private Methods

    /// 요청마다 호출되는 경로라 읽기·해석 실패도 오류로 던지지 않고 비로그인(`nil`)으로 간주한다.
    private func loadStoredToken() -> StoredToken? {
        guard let data = try? keychain.load(for: Self.tokenKey) else { return nil }

        return try? JSONDecoder().decode(StoredToken.self, from: data)
    }

    // MARK: - TokenProvider (Network)

    public func accessToken() async -> String? {
        loadAccessToken()
    }
}
