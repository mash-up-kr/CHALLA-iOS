import Foundation

/// 설정 값을 기기에 담아두는 키-값 저장소 추상.
///
/// `UserDefaults`를 직접 쓰지 않고 한 겹 두는 이유는 테스트 때문이다 —
/// 실제 `UserDefaults`를 쓰면 테스트끼리 상태가 새고 실행 순서에 결과가 흔들린다.
public protocol SettingsStorage: Sendable {
    func bool(forKey key: String) -> Bool?
    func setBool(_ value: Bool, forKey key: String)
}

/// `UserDefaults` 기반 구현.
///
/// `@unchecked Sendable`인 이유: `UserDefaults`는 스레드 안전하다고 문서화되어 있지만
/// `Sendable`을 채택하고 있지 않다. 내부 상태를 따로 갖지 않으므로 안전하다.
public struct UserDefaultsSettingsStorage: SettingsStorage, @unchecked Sendable {

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 값이 없을 때 `false`가 아니라 `nil`을 돌려준다 —
    /// "설정한 적 없음"과 "꺼둠"을 구분해야 도메인의 기본값 규칙을 적용할 수 있다.
    public func bool(forKey key: String) -> Bool? {
        defaults.object(forKey: key) as? Bool
    }

    public func setBool(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
