@testable import SettingFeature
import ComposableArchitecture
import Foundation
import SettingDomain

/// 저장소를 하나로 고정한 채 테마를 시드하고 그 안에서 스토어를 만든다.
///
/// 테스트의 `defaultAppStorage`는 읽을 때마다 새 suite를 만든다. 시드와 스토어가 각각 읽으면
/// 서로 다른 저장소를 보게 되고, 시드한 값이 스토어에 반영되지 않는다.
/// 그래서 둘을 같은 컨텍스트 안에서 만든다.
@MainActor
func withThemeStorage<T>(seeding theme: AppTheme? = nil, _ body: () -> T) -> T {
    // Sharing이 제공하는 일회용 저장소 — 호출할 때마다 새 suite를 만든다.
    let defaults = UserDefaults.inMemory

    return withDependencies {
        $0.defaultAppStorage = defaults
    } operation: {
        if let theme {
            @Shared(.appTheme) var shared
            $shared.withLock { $0 = theme }
        }
        return body()
    }
}
