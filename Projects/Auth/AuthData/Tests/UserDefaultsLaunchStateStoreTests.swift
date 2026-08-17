import AuthData
import Foundation
import Testing

@Suite("UserDefaultsLaunchStateStore")
struct UserDefaultsLaunchStateStoreTests {

    /// 테스트끼리 상태가 새지 않도록 실행마다 별도 suite name을 쓴다.
    private func makeDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "com.challa.launchstate.tests.\(UUID().uuidString)"))
    }

    @Test("처음에는 실행 이력이 없다 — 재설치 직후로 판정된다")
    func startsWithoutLaunchHistory() throws {
        let store = try UserDefaultsLaunchStateStore(defaults: makeDefaults())

        #expect(store.hasLaunchedBefore == false)
    }

    @Test("markLaunched 후에는 실행 이력이 남는다")
    func marksLaunched() throws {
        let store = try UserDefaultsLaunchStateStore(defaults: makeDefaults())

        store.markLaunched()

        #expect(store.hasLaunchedBefore)
    }

    @Test("기록은 같은 저장소를 보는 다른 인스턴스에도 보인다 (다음 실행에서 읽힌다)")
    func recordSurvivesNewInstance() throws {
        let defaults = try makeDefaults()
        UserDefaultsLaunchStateStore(defaults: defaults).markLaunched()

        #expect(UserDefaultsLaunchStateStore(defaults: defaults).hasLaunchedBefore)
    }
}
