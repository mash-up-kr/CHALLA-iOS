@testable import SettingData
import Foundation

/// 테스트용 인메모리 저장소. 실제 `UserDefaults`를 쓰면 테스트끼리 상태가 샌다.
final class InMemorySettingsStorage: SettingsStorage, @unchecked Sendable {

    private var bools: [String: Bool] = [:]

    init(bools: [String: Bool] = [:]) {
        self.bools = bools
    }

    func bool(forKey key: String) -> Bool? {
        bools[key]
    }

    func setBool(_ value: Bool, forKey key: String) {
        bools[key] = value
    }
}
