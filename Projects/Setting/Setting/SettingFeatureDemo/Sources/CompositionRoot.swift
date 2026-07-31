import ComposableArchitecture
import Foundation
import SettingData
import SettingDomain

/// 데모앱의 의존성 조립 지점 — 이 앱에서 유일하게 Data 구현체를 생성하는 곳.
///
/// 데모앱은 앱 조립 지점이므로 예외적으로 `SettingData`를 import 할 수 있다 (아키텍처 규칙 2의 유일한 예외).
/// `CHALLAApp/Sources/CompositionRoot.swift`가 같은 형태의 배선을 갖는다.
enum CompositionRoot {

    /// 요청한 상태에 맞는 의존성을 등록한다.
    static func register(
        state: DemoLaunchArguments.State,
        into values: inout DependencyValues
    ) {
        switch state {
        case .default:
            // 테마·알림은 실제 로컬 저장소를 읽고 쓴다. 프로필만 스텁이다 (#33 머지 후 교체).
            values.loadSettingsUseCase = .live(
                settings: DefaultSettingsRepository(),
                profile: StubProfileProvider()
            )

        case .loading:
            // 끝나지 않는 이펙트 — 로딩 상태로 멈춰 있게 한다.
            values.loadSettingsUseCase = LoadSettingsUseCase(run: {
                try await Task.sleep(for: .seconds(60 * 60))
                throw SettingError.unknown
            })

        case .error:
            values.loadSettingsUseCase = LoadSettingsUseCase(run: {
                throw SettingError.network
            })
        }
    }
}
