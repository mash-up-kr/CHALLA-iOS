import CameraSession
import ComposableArchitecture
import SwiftUI

struct DemoRootView: View {

    /// 실행 인자로 시나리오가 들어오면 그 화면만 바로 띄운다 (시뮬레이터를 탭할 수 없어서).
    let launchedScenario: DemoScenario?

    /// 실기기 카메라 세션. 리듀서(`CameraDemoFeature`)와 프리뷰가 같은 세션을 봐야 하므로
    /// `@Dependency`로 공유되는 live 인스턴스를 그대로 뷰에서도 가져와 프리뷰에 넘긴다.
    @Dependency(\.cameraSession) private var cameraSession

    var body: some View {
        if let launchedScenario {
            CameraEntryView(scenario: launchedScenario, cameraSession: cameraSession)
        } else {
            scenarioList
        }
    }

    private var scenarioList: some View {
        NavigationStack {
            List(DemoScenario.all, id: \.label) { scenario in
                NavigationLink(scenario.label) {
                    CameraEntryView(scenario: scenario, cameraSession: cameraSession)
                        .toolbar(.hidden, for: .navigationBar)
                }
            }
            .navigationTitle("카메라 데모")
        }
    }
}

#Preview {
    DemoRootView(launchedScenario: nil)
}
