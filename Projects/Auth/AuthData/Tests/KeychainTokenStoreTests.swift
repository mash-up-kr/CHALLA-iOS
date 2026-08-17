@testable import AuthData
import AuthDomain
import Foundation
import Keychain
import Testing

/// `TokenStore`(Domain)와 `TokenProvider`(Network)를 한 Keychain 위에서 동시에 만족시키는 접점.
/// Keychain 자체는 `MockKeychain`으로 대체해 저장/조회 로직만 검증한다.
@Suite("KeychainTokenStore")
struct KeychainTokenStoreTests {

    private static let token = AuthToken(accessToken: "access", refreshToken: "refresh")

    @Test("save한 토큰 쌍이 access·refresh로 각각 라운드트립된다")
    func saveRoundTrips() throws {
        let store = KeychainTokenStore(keychain: MockKeychain())

        try store.save(Self.token)

        #expect(store.loadAccessToken() == "access")
        #expect(store.loadRefreshToken() == "refresh")
    }

    @Test("저장 전에는 두 토큰 조회가 모두 nil이다")
    func loadsNilBeforeSave() {
        let store = KeychainTokenStore(keychain: MockKeychain())

        #expect(store.loadAccessToken() == nil)
        #expect(store.loadRefreshToken() == nil)
    }

    @Test("clear는 access·refresh를 모두 지운다")
    func clearRemovesBoth() throws {
        let store = KeychainTokenStore(keychain: MockKeychain())
        try store.save(Self.token)

        try store.clear()

        #expect(store.loadAccessToken() == nil)
        #expect(store.loadRefreshToken() == nil)
    }

    @Test("clear는 토큰 항목뿐 아니라 같은 service의 다른 항목까지 비운다")
    func clearWipesWholeService() throws {
        let keychain = MockKeychain()
        let store = KeychainTokenStore(keychain: keychain)
        try store.save(Self.token)
        try keychain.save(Data("legacy".utf8), for: "challa.auth.legacy")

        try store.clear()

        #expect(keychain.itemCount == 0)
    }

    @Test("TokenProvider.accessToken()은 저장된 accessToken을 돌려준다")
    func tokenProviderReadsAccessToken() async throws {
        let store = KeychainTokenStore(keychain: MockKeychain())
        try store.save(Self.token)

        #expect(await store.accessToken() == "access")
    }

    @Test("save 실패는 그대로 전파된다 (정규화는 상위 UseCase 몫)")
    func saveFailurePropagates() {
        let store = KeychainTokenStore(keychain: MockKeychain(shouldFailOnSave: true))

        #expect(throws: MockKeychain.InjectedFailure.self) {
            try store.save(Self.token)
        }
    }

    @Test("save가 실패해도 직전 토큰 쌍이 온전히 남는다 (부분 저장 없음)")
    func saveFailureKeepsPreviousPairIntact() throws {
        let keychain = MockKeychain()
        let store = KeychainTokenStore(keychain: keychain)
        try store.save(AuthToken(accessToken: "old-access", refreshToken: "old-refresh"))

        keychain.setFailOnSave(true)
        #expect(throws: MockKeychain.InjectedFailure.self) {
            try store.save(AuthToken(accessToken: "new-access", refreshToken: "new-refresh"))
        }

        // 새 access + 옛 refresh 같은 불일치 조합이 생기면 안 된다.
        #expect(store.loadAccessToken() == "old-access")
        #expect(store.loadRefreshToken() == "old-refresh")
    }

    @Test("토큰 쌍은 단일 항목으로 저장된다 (키체인 호출이 나뉘지 않음)")
    func storesBothTokensAsSingleItem() throws {
        let keychain = MockKeychain()
        let store = KeychainTokenStore(keychain: keychain)

        try store.save(Self.token)

        #expect(keychain.itemCount == 1)
    }

    @Test("clear 실패는 그대로 전파된다 (토큰이 남았음을 상위가 알아야 한다)")
    func clearFailurePropagates() throws {
        let keychain = MockKeychain(shouldFailOnDelete: true)
        let store = KeychainTokenStore(keychain: keychain)
        try store.save(Self.token)

        #expect(throws: MockKeychain.InjectedFailure.self) {
            try store.clear()
        }
    }

    @Test("조회 실패는 오류를 삼켜 nil로 돌려준다 (요청마다 호출되는 경로라 방어적)")
    func loadFailureBecomesNil() {
        let store = KeychainTokenStore(keychain: MockKeychain(shouldFailOnLoad: true))

        #expect(store.loadAccessToken() == nil)
        #expect(store.loadRefreshToken() == nil)
    }
}
