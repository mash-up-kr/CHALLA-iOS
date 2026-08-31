import ComposableArchitecture
import PhotoDetailFeature
import SwiftUI

/// 데모 진입 화면.
///
/// 실행 인자로 화면을 지정하면 그 화면을 바로 띄우고, 없으면 상태를 고르는 목록을 보여준다.
struct DemoRootView: View {

    private let arguments = DemoLaunchArguments.parse()

    var body: some View {
        if let screen = arguments.screen {
            switch screen {
            case .photoDetail:
                PhotoDetailDemoScreen(demoState: arguments.state)
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
                        PhotoDetailDemoScreen(demoState: state)
                    }
                }
            }
            .navigationTitle("사진 상세 데모")
        }
    }

    private func title(of state: DemoLaunchArguments.State) -> String {
        switch state {
        case .default: "기본 (사진 5장)"
        case .loading: "로딩"
        case .empty: "사진 없음"
        case .error: "조회 실패"
        }
    }
}

/// 데모에서 App 역할을 대신하는 부모 리듀서.
/// 사진 상세가 닫기를 요청하면 플래그를 세우고, 실제 닫기는 뷰가 SwiftUI dismiss로 한다.
@Reducer
private struct DemoDetailFeature {

    @ObservableState
    struct State: Equatable {
        var detail: PhotoDetailFeature.State
        var isDismissed = false
    }

    enum Action {
        case detail(PhotoDetailFeature.Action)
        case dismissHandled
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.detail, action: \.detail) {
            PhotoDetailFeature()
        }
        Reduce { state, action in
            switch action {
            case .detail(.delegate(.closeRequested)):
                state.isDismissed = true
                return .none
            case .dismissHandled:
                // 화면을 다시 열었을 때 또 닫히도록 플래그를 되돌린다.
                state.isDismissed = false
                return .none
            case .detail:
                return .none
            }
        }
    }
}

/// 상태 하나에 맞춰 조립한 사진 상세 화면.
private struct PhotoDetailDemoScreen: View {

    @Environment(\.dismiss) private var dismiss

    /// body가 다시 평가돼도 Store가 새로 만들어지지 않도록 @State로 들고 있는다.
    @State private var store: StoreOf<DemoDetailFeature>

    init(demoState: DemoLaunchArguments.State) {
        _store = State(
            initialValue: Store(
                initialState: DemoDetailFeature.State(
                    detail: PhotoDetailFeature.State(
                        roomID: DemoFixture.roomID,
                        roomTitle: DemoFixture.roomTitle,
                        currentUserID: DemoFixture.currentUserID
                    )
                )
            ) {
                DemoDetailFeature()
            } withDependencies: {
                CompositionRoot.registerDependencies(for: demoState, into: &$0)
            }
        )
    }

    var body: some View {
        PhotoDetailView(store: store.scope(state: \.detail, action: \.detail))
            .onChange(of: store.isDismissed) { _, isDismissed in
                if isDismissed {
                    dismiss()
                    store.send(.dismissHandled)
                }
            }
    }
}
