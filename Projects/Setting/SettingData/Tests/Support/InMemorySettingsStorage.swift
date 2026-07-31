@testable import SettingData
import Foundation

/// 테스트용 인메모리 저장소. 실제 `UserDefaults`를 쓰면 테스트끼리 상태가 샌다.
final class InMemorySettingsStorage: SettingsStorage, @unchecked Sendable {

    private var strings: [String: String] = [:]
    private var bools: [String: Bool] = [:]

    init(strings: [String: String] = [:], bools: [String: Bool] = [:]) {
        self.strings = strings
        self.bools = bools
    }

    func string(forKey key: String) -> String? {
        strings[key]
    }

    func setString(_ value: String, forKey key: String) {
        strings[key] = value
    }

    func bool(forKey key: String) -> Bool? {
        bools[key]
    }

    func setBool(_ value: Bool, forKey key: String) {
        bools[key] = value
    }
}
