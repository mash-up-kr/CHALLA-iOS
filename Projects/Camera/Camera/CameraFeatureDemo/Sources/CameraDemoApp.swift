import SwiftUI

@main
struct CameraDemoApp: App {

    private let launchedScenario = DemoScenario.fromLaunchArguments()

    var body: some Scene {
        WindowGroup {
            DemoRootView(launchedScenario: launchedScenario)
        }
    }
}
