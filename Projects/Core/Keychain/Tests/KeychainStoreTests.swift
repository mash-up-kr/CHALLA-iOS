@testable import Keychain
import Foundation
import Security
import Testing

@Suite("KeychainStore")
struct KeychainStoreTests {

    private let key = "test.key"

    /// 테스트마다 고유 service를 써서 병렬 실행·이전 실행 잔여물과 간섭하지 않게 한다.
    private func makeService() -> String {
        "com.challa.keychain.tests.\(UUID().uuidString)"
    }

    private func makeStore() -> KeychainStore {
        KeychainStore(service: makeService())
    }

    /// 해당 service에 실제로 남아 있는 항목 수. `KeychainStore`를 거치지 않고 SecItem에 직접 묻는다.
    private func itemCount(service: String) -> Int {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: kCFBooleanTrue as Any
        ]

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return 0
        }
        return (result as? [[String: Any]])?.count ?? 0
    }

    @Test("저장한 데이터를 그대로 조회한다 (라운드트립)")
    func saveThenLoadRoundTrip() throws {
        let store = makeStore()
        defer { try? store.delete(for: key) }

        let data = Data("secret-token".utf8)
        try store.save(data, for: key)

        #expect(try store.load(for: key) == data)
    }

    @Test("저장한 적 없는 키는 nil을 돌려준다 (오류 아님)")
    func loadMissingKeyReturnsNil() throws {
        let store = makeStore()

        #expect(try store.load(for: key) == nil)
    }

    @Test("삭제 후 조회하면 nil이다")
    func deleteThenLoadReturnsNil() throws {
        let store = makeStore()

        try store.save(Data("value".utf8), for: key)
        try store.delete(for: key)

        #expect(try store.load(for: key) == nil)
    }

    @Test("없는 키를 삭제해도 오류를 던지지 않는다")
    func deleteMissingKeyDoesNotThrow() throws {
        let store = makeStore()

        try store.delete(for: key)
    }

    @Test("deleteAll은 service 안의 모든 항목을 지운다 (키를 몰라도 초기화된다)")
    func deleteAllRemovesEveryItem() throws {
        let service = makeService()
        let store = KeychainStore(service: service)
        defer { try? store.deleteAll() }

        try store.save(Data("a".utf8), for: "key.a")
        try store.save(Data("b".utf8), for: "key.b")

        try store.deleteAll()

        #expect(itemCount(service: service) == 0)
        #expect(try store.load(for: "key.a") == nil)
        #expect(try store.load(for: "key.b") == nil)
    }

    @Test("deleteAll은 다른 service의 항목까지 지우지 않는다")
    func deleteAllStaysWithinService() throws {
        let storeA = makeStore()
        let storeB = makeStore()
        defer { try? storeB.deleteAll() }

        try storeA.save(Data("a".utf8), for: key)
        try storeB.save(Data("b".utf8), for: key)

        try storeA.deleteAll()

        #expect(try storeB.load(for: key) == Data("b".utf8))
    }

    @Test("빈 service를 deleteAll해도 오류를 던지지 않는다")
    func deleteAllOnEmptyServiceDoesNotThrow() throws {
        let store = makeStore()

        try store.deleteAll()
    }

    @Test("같은 키에 두 번 저장하면 최신값으로 덮어쓴다")
    func saveTwiceOverwrites() throws {
        let store = makeStore()
        defer { try? store.delete(for: key) }

        try store.save(Data("old".utf8), for: key)
        try store.save(Data("new".utf8), for: key)

        #expect(try store.load(for: key) == Data("new".utf8))
    }

    @Test("덮어써도 항목은 하나만 유지된다 (update 경로 — 중복 생성 없음)")
    func saveTwiceKeepsSingleItem() throws {
        let service = makeService()
        let store = KeychainStore(service: service)
        defer { try? store.delete(for: key) }

        try store.save(Data("first".utf8), for: key)
        try store.save(Data("second".utf8), for: key)

        #expect(itemCount(service: service) == 1)
    }

    @Test("첫 저장은 add 경로로 항목을 만든다")
    func firstSaveCreatesItem() throws {
        let service = makeService()
        let store = KeychainStore(service: service)
        defer { try? store.delete(for: key) }

        #expect(itemCount(service: service) == 0)

        try store.save(Data("value".utf8), for: key)

        #expect(itemCount(service: service) == 1)
    }

    @Test("service가 다르면 같은 키라도 서로 격리된다")
    func differentServicesAreIsolated() throws {
        let storeA = makeStore()
        let storeB = makeStore()
        defer { try? storeA.delete(for: key) }

        try storeA.save(Data("a-only".utf8), for: key)

        #expect(try storeB.load(for: key) == nil)
    }

    // MARK: - String 편의 확장

    @Test("문자열 저장·조회 라운드트립 (saveString/loadString)")
    func stringRoundTrip() throws {
        let store = makeStore()
        defer { try? store.delete(for: key) }

        try store.saveString("액세스토큰-abc123", for: key)

        #expect(try store.loadString(for: key) == "액세스토큰-abc123")
    }

    @Test("문자열 조회 — 없는 키는 nil")
    func loadStringMissingKeyReturnsNil() throws {
        let store = makeStore()

        #expect(try store.loadString(for: key) == nil)
    }

    @Test("UTF-8 문자열이 아닌 데이터를 loadString하면 dataConversionFailed")
    func loadStringNonUTF8Throws() throws {
        let store = makeStore()
        defer { try? store.delete(for: key) }

        try store.save(Data([0xFF, 0xFE, 0xFD]), for: key) // 유효하지 않은 UTF-8

        #expect(throws: KeychainError.dataConversionFailed) {
            try store.loadString(for: key)
        }
    }
}
