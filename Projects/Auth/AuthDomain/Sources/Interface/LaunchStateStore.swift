import Foundation

/// 앱이 이 기기에서 실행된 적 있는지 기록하는 저장소.
///
/// 키체인은 앱을 삭제해도 남을 수 있어서, 재설치 직후에 이전 설치의 토큰이 그대로 살아난다.
/// 앱과 함께 사라지는 저장소(`UserDefaults` 등)에 플래그를 두고 그것과 비교해 재설치를 판정한다.
public protocol LaunchStateStore: Sendable {

    var hasLaunchedBefore: Bool { get }

    func markLaunched()
}
