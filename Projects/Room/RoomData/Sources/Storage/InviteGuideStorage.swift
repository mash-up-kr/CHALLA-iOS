import Foundation

/// 초대 안내 기록을 기기에 담아두는 키-값 저장소 추상.
/// `DefaultInviteGuideRepository`가 실행 앱에서는 `UserDefaults` 구현으로 읽고 쓰고,
/// 테스트에서는 메모리 구현으로 갈아끼운다 — 실제 `UserDefaults`는 기기 전역이라
/// 한 테스트가 남긴 기록이 다음 테스트에 읽힌다.
public protocol InviteGuideStorage: Sendable {
    func bool(forKey key: String) -> Bool
    func setBool(_ value: Bool, forKey key: String)
}

/// `UserDefaults` 기반 구현. 내부 상태가 없어 `@unchecked Sendable`이 안전하다
/// (`UserDefaults` 자체는 스레드 안전하지만 `Sendable` 채택이 없다).
public struct UserDefaultsInviteGuideStorage: InviteGuideStorage, @unchecked Sendable {

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 기록이 없으면 false — "아직 안 봄"과 같은 뜻이라 두 경우를 구분하지 않는다.
    public func bool(forKey key: String) -> Bool {
        defaults.bool(forKey: key)
    }

    public func setBool(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
