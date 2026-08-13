import ComposableArchitecture
import PhotoDetailFeature
import SwiftUI

/// 데모 진입 화면.
///
/// 실행 인자로 화면을 지정하면 그 화면이 바로 뜨고(시안 대조용),
/// 지정하지 않으면 상태를 골라 들어가는 목록을 보여준다.
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

/// 데모가 App의 조립을 흉내내는 얇은 parent — 사진 상세의 `closeRequested`를 받아 닫힘 신호를 세운다.
/// 실배포앱에서는 이 자리를 네비게이션을 조립하는 App이 맡는다 (아키텍처 규칙 3).
///
/// 데모는 SwiftUI `NavigationLink`로 화면을 띄우므로 TCA의 `@Dependency(\.dismiss)`가 아니라
/// 뷰의 `@Environment(\.dismiss)`로 닫는다 — 그래서 리듀서는 상태 플래그만 세우고 실제 닫기는 뷰가 한다.
@Reducer
private struct DemoDetailFeature {

    @ObservableState
    struct State: Equatable {
        var detail: PhotoDetailFeature.State
        var isDismissed = false
    }

    enum Action {
        case detail(PhotoDetailFeature.Action)
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
            // 목록에서 push된 경우 pop된다. --screen으로 root에 바로 띄운 경우엔 닫을 곳이 없어 무시된다(경고 없음).
            .onChange(of: store.isDismissed) { _, isDismissed in
                if isDismissed {
                    dismiss()
                }
            }
    }
}
