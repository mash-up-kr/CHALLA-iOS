import AuthDomain
import Foundation

/// 앱을 삭제하면 함께 지워지는 `UserDefaults`에 실행 이력을 남긴다 —
/// 재설치 후에도 남아 있을 수 있는 키체인과 대조해 "설치 후 최초 실행"을 판정한다.
///
/// `@unchecked Sendable`인 이유: `UserDefaults`는 스레드 안전하다고 문서화됐지만 `Sendable`을 채택하지 않는다.
/// 이 타입은 내부 상태를 따로 갖지 않으므로 안전하다.
public struct UserDefaultsLaunchStateStore: LaunchStateStore, @unchecked Sendable {

    private static let key = "challa.launch.hasLaunchedBefore"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hasLaunchedBefore: Bool {
        defaults.bool(forKey: Self.key)
    }

    public func markLaunched() {
        defaults.set(true, forKey: Self.key)
    }
}
