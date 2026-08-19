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

/// 상태 하나에 맞춰 조립한 사진 상세 화면.
private struct PhotoDetailDemoScreen: View {

    /// body가 다시 평가돼도 Store가 새로 만들어지지 않도록 @State로 들고 있는다.
    @State private var store: StoreOf<PhotoDetailFeature>

    init(demoState: DemoLaunchArguments.State) {
        _store = State(
            initialValue: Store(
                initialState: PhotoDetailFeature.State(
                    roomID: DemoFixture.roomID,
                    roomTitle: DemoFixture.roomTitle,
                    currentUserID: DemoFixture.currentUserID
                )
            ) {
                PhotoDetailFeature()._printChanges()
            } withDependencies: {
                CompositionRoot.registerDependencies(for: demoState, into: &$0)
            }
        )
    }

    var body: some View {
        PhotoDetailView(store: store)
    }
}
