import ChatDomain
import ComposableArchitecture
import Foundation

/// 데모의 의존성 조립 지점. 여기서만 구체 구현을 만든다.
enum CompositionRoot {

    static func registerDependencies(
        for demoState: DemoLaunchArguments.State,
        into values: inout DependencyValues
    ) {
        let repository = DemoChatRepository(scenario: scenario(for: demoState))

        values.fetchChatsUseCase = .live(repository: repository)
        values.sendChatUseCase = .live(repository: repository)
    }

    private static func scenario(for demoState: DemoLaunchArguments.State) -> DemoChatRepository.Scenario {
        switch demoState {
        case .default, .printWaiting: .populated(DemoChatStore(messages: DemoFixture.messages()))
        case .loading: .neverFinishes
        case .empty: .empty
        case .error: .failure(.network)
        }
    }
}
