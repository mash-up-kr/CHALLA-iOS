import Foundation

/// 카메라 온보딩 기록을 기기에 담아두는 키-값 저장소 추상.
///
/// `UserDefaults`를 직접 쓰지 않고 한 겹 두는 이유는 테스트 때문이다 —
/// 실제 `UserDefaults`를 쓰면 테스트끼리 상태가 새고 실행 순서에 결과가 흔들린다.
/// (`SettingData.SettingsStorage`와 같은 판단이지만, Data 모듈끼리 import 하지 않으려고 따로 둔다.)
public protocol CameraOnboardingStorage: Sendable {
    func bool(forKey key: String) -> Bool
    func setBool(_ value: Bool, forKey key: String)
}

/// `UserDefaults` 기반 구현.
///
/// `@unchecked Sendable`인 이유: `UserDefaults`는 스레드 안전하다고 문서화되어 있지만
/// `Sendable`을 채택하고 있지 않다. 내부 상태를 따로 갖지 않으므로 안전하다.
public struct UserDefaultsCameraOnboardingStorage: CameraOnboardingStorage, @unchecked Sendable {

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 기록이 없으면 false — "아직 안 봄"과 같은 뜻이라 두 경우를 구분할 필요가 없다.
    public func bool(forKey key: String) -> Bool {
        defaults.bool(forKey: key)
    }

    public func setBool(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
