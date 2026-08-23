import ChatRoomFeature
import ComposableArchitecture
import SwiftUI

/// 데모 진입 화면. 실행 인자로 화면을 지정하면 그 화면을 바로 띄우고, 없으면 상태를 고르는 목록을 보여준다.
struct DemoRootView: View {

    private let arguments = DemoLaunchArguments.parse()

    var body: some View {
        if let screen = arguments.screen {
            switch screen {
            case .chatRoom:
                ChatRoomDemoScreen(demoState: arguments.state)
            }
        } else {
            statePicker
        }
    }

    private var statePicker: some View {
        NavigationStack {
            List {
                ForEach(DemoLaunchArguments.State.allCases, id: \.self) { state in
                    NavigationLink(title(of: state)) {
                        ChatRoomDemoScreen(demoState: state)
                    }
                }
            }
            .navigationTitle("채팅 데모")
        }
    }

    private func title(of state: DemoLaunchArguments.State) -> String {
        switch state {
        case .default: "기본 (메시지 있음)"
        case .loading: "로딩"
        case .empty: "메시지 없음"
        case .error: "조회 실패"
        }
    }
}

/// 데모에서 App 역할을 대신하는 부모 리듀서. 닫기 요청을 플래그로 받고, 실제 닫기는 뷰가 SwiftUI dismiss로 한다.
@Reducer
private struct DemoChatFeature {

    @ObservableState
    struct State: Equatable {
        var chat: ChatRoomFeature.State
        var isDismissed = false
    }

    enum Action {
        case chat(ChatRoomFeature.Action)
        case dismissHandled
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.chat, action: \.chat) {
            ChatRoomFeature()
        }
        Reduce { state, action in
            switch action {
            case .chat(.delegate(.closeRequested)):
                state.isDismissed = true
                return .none
            case .dismissHandled:
                state.isDismissed = false
                return .none
            case .chat:
                return .none
            }
        }
    }
}

private struct ChatRoomDemoScreen: View {

    @Environment(\.dismiss) private var dismiss
    @State private var store: StoreOf<DemoChatFeature>

    init(demoState: DemoLaunchArguments.State) {
        _store = State(
            initialValue: Store(
                initialState: DemoChatFeature.State(
                    chat: ChatRoomFeature.State(
                        roomID: DemoFixture.roomID,
                        roomTitle: DemoFixture.roomTitle,
                        currentUserNickname: DemoFixture.currentUserNickname
                    )
                )
            ) {
                DemoChatFeature()
            } withDependencies: {
                CompositionRoot.registerDependencies(for: demoState, into: &$0)
            }
        )
    }

    var body: some View {
        ChatRoomView(store: store.scope(state: \.chat, action: \.chat))
            .onChange(of: store.isDismissed) { _, isDismissed in
                if isDismissed {
                    dismiss()
                    store.send(.dismissHandled)
                }
            }
    }
}
