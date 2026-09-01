import AuthDomain
import ComposableArchitecture
import LoginFeature
import SwiftUI

/// 데모 진입 화면 — 실서버 / Mock 두 구성으로 로그인 화면을 띄운다.
struct DemoRootView: View {

    /// 구성 1: 실제 구체 어댑터를 조립해 주입 — 카카오/애플 SDK · 실서버 · Keychain까지 실동작.
    @State private var liveStore = Store(initialState: LoginFeature.State()) {
        LoginFeature()._printChanges()
    } withDependencies: {
        CompositionRoot.registerLiveDependencies(into: &$0)
    }

    /// 구성 2: Mock 주입 — SDK/서버 없이 화면·리듀서 흐름만 검증.
    @State private var mockStore = Store(initialState: LoginFeature.State()) {
        LoginFeature()._printChanges()
    } withDependencies: {
        $0.loginUseCase = LoginUseCase(run: { _ in
            try await Task.sleep(for: .seconds(1))
            return LoginResult(isNewUser: true)
        })
    }

    var body: some View {
        // 실행 인자 진입 규약 (--screen login) — 시뮬레이터를 탭 없이 UI 검증하기 위한 통로.
        if Self.launchArgumentValue(for: "--screen") == "login" {
            LoginView(store: mockStore)
        } else {
            NavigationStack {
                List {
                    NavigationLink("실서버(AuthData) 로그인") { LoginView(store: liveStore) }
                    NavigationLink("Mock 로그인 (신규 유저)") { LoginView(store: mockStore) }
                }
                .navigationTitle("로그인 데모")
            }
        }
    }

    /// 실행 인자에서 플래그 바로 다음 값을 읽는다 (예: `--screen login` → "login").
    /// 잘못된 인자는 무시하고 기본 화면으로 뜬다 (다른 데모앱들의 파싱 정책과 동일).
    private static func launchArgumentValue(for flag: String) -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1)
        else { return nil }
        return arguments[index + 1]
    }
}
