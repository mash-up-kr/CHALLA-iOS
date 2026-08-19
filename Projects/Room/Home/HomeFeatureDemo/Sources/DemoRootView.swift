import ComposableArchitecture
import HomeFeature
import SwiftUI

/// 인자 없이 Xcode에서 Run 했을 때 뜨는 화면 선택 목록.
///
/// 검증은 실행 인자로 화면을 바로 띄우지만, 사람이 눌러볼 때는 골라 들어가는 편이 빠르다.
/// 항목 이름을 인자 그대로 적어 두어, 여기서 본 화면을 인자로도 바로 띄울 수 있다.
struct DemoRootView: View {

    var body: some View {
        NavigationStack {
            List {
                Section("목록 (--screen list)") {
                    ForEach(DemoScreen.ListState.allCases, id: \.self) { state in
                        NavigationLink("--state \(state.rawValue)", value: DemoScreen.list(state))
                    }
                }

                Section("겹쳐 뜨는 화면") {
                    NavigationLink("--screen menu", value: DemoScreen.menu)
                    ForEach(DemoScreen.DrawerState.allCases, id: \.self) { state in
                        NavigationLink(
                            "--screen create --state \(state.rawValue)",
                            value: DemoScreen.create(state)
                        )
                    }
                    ForEach(DemoScreen.DrawerState.allCases, id: \.self) { state in
                        NavigationLink(
                            "--screen join --state \(state.rawValue)",
                            value: DemoScreen.join(state)
                        )
                    }
                }
            }
            .navigationTitle("홈 데모")
            .navigationDestination(for: DemoScreen.self) { screen in
                DemoScreenView(screen: screen)
            }
        }
    }
}

/// 목록에서 고른 화면.
///
/// 홈이 자기 상단 바를 그리므로 NavigationStack의 바는 숨기고, 대신 목록으로 돌아가는
/// 버튼을 화면 위에 얹는다. 실행 인자로 바로 띄운 화면에는 이 버튼이 붙지 않는다 —
/// 시안 대조 스크린샷에 데모용 장치가 찍히면 안 되기 때문이다.
private struct DemoScreenView: View {

    @State private var store: StoreOf<HomeFeature>

    @Environment(\.dismiss) private var dismiss

    init(screen: DemoScreen) {
        // 화면이 다시 그려질 때마다 스토어가 새로 만들어지면 입력값도 조회 결과도 초기화된다.
        _store = State(initialValue: DemoStore.make(for: screen))
    }

    var body: some View {
        HomeView(store: store)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                Button("목록") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .padding(16)
            }
    }
}
