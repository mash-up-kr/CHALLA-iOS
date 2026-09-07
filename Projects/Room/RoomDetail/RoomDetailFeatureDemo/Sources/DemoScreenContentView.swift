import ComposableArchitecture
import RoomDetailFeature
import SwiftUI

/// 화면 종류별 실제 뷰. 실행 인자 진입(RoomDetailDemoApp)과 목록 진입(DemoRootView)이 같이 쓴다.
///
/// 스토어는 화면별 하위 뷰가 `@State`로 한 번만 만든다 — 다시 그려질 때마다 새로 만들면
/// 조회 결과가 초기화되고 이미지 로드도 처음부터 다시 시작한다.
struct DemoScreenContentView: View {

    let screen: DemoScreen

    var body: some View {
        switch screen {
        case let .detail(state): DetailContent(state: state)
        case let .settings(state): SettingsContent(state: state)
        }
    }
}

private struct DetailContent: View {

    @State private var store: StoreOf<RoomDetailFeature>

    init(state: DemoScreen.DetailState) {
        _store = State(initialValue: DemoStore.makeDetail(for: state))
    }

    var body: some View {
        RoomDetailView(store: store)
    }
}

private struct SettingsContent: View {

    @State private var store: StoreOf<RoomSettingsFeature>

    init(state: DemoScreen.SettingsState) {
        _store = State(initialValue: DemoStore.makeSettings(for: state))
    }

    var body: some View {
        RoomSettingsView(store: store)
    }
}
