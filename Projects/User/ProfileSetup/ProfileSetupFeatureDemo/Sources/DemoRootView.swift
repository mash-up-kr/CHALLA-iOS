import ComposableArchitecture
import ProfileSetupFeature
import SwiftUI

/// 실행 인자로 조립한 시나리오 하나를 바로 띄운다.
struct DemoRootView: View {

    /// @State 보관 — View 재생성(환경 변화)에도 Store identity가 유지된다.
    @State private var store: StoreOf<ProfileSetupFeature>

    init() {
        let scenario = DemoScenario(arguments: ProcessInfo.processInfo.arguments)
        _store = State(
            wrappedValue: Store(initialState: scenario.initialState) {
                ProfileSetupFeature()._printChanges() // delegate 발화를 콘솔로 확인
            } withDependencies: {
                CompositionRoot.registerMockDependencies(into: &$0, outcome: scenario.outcome)
            }
        )
    }

    var body: some View {
        // 데모에는 parent가 없으므로 delegate(.setupCompleted)는 소비되지 않고 환영 화면이 유지된다.
        ProfileSetupView(store: store)
    }
}
