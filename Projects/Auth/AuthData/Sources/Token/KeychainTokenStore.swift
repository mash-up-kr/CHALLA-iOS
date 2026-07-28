import AuthDomain
import CHALLANetwork
import Foundation
import Keychain

/// 하나의 Keychain 위에서 Domain의 `TokenStore`와 Network의 `TokenProvider`를 동시에 만족시킨다.
///
/// `LoginUseCase.live`가 `TokenStore.save`로 저장한 토큰을,
/// `AuthInterceptor`가 `TokenProvider.accessToken()`으로 요청마다 읽어간다 —
/// 두 프로토콜의 접점이 이 타입 하나뿐이라 저장 위치(Keychain)가 밖으로 새지 않는다.
///
/// 조립 지점(Demo앱/추후 DIContainer)이 다른 Data 모듈의 HTTPClient에도
/// 같은 인스턴스를 꽂아야 하므로 public이다.
///
/// 저장 프로퍼티가 불변 `keychain` 하나뿐인 final class라 `Sendable`이 자연 성립한다 (`@unchecked` 미사용).
public final class KeychainTokenStore: TokenStore, TokenProvider {

    // MARK: - Properties

    private let keychain: any Keychain

    /// 토큰 쌍을 담는 단일 항목의 키.
    ///
    /// access·refresh를 두 키로 나누지 않는 이유: 키체인에는 트랜잭션이 없어서 앞의 저장만
    /// 성공하면 *새 access + 옛 refresh* 불일치가 남는다(갱신을 서버가 거부 → 로그아웃).
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

    /// 저장된 토큰 쌍. 없거나 읽기·해석에 실패하면 `nil`.
    ///
    /// 요청마다(`AuthInterceptor`) 호출되는 경로라 오류를 던지지 않고 비로그인으로 간주한다.
    private func loadStoredToken() -> StoredToken? {
        // `try?`가 중첩 옵셔널을 평탄화해 "읽기 실패"와 "항목 없음"이 함께 nil이 된다.
        guard let data = try? keychain.load(for: Self.tokenKey) else { return nil }

        return try? JSONDecoder().decode(StoredToken.self, from: data)
    }

    // MARK: - TokenProvider (Network)

    /// `AuthInterceptor`가 요청마다 호출한다.
    public func accessToken() async -> String? {
        loadAccessToken()
    }
}
