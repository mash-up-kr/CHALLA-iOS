import SwiftUI
import Foundation
import ComposableArchitecture
import LoginFeature
import AuthDomain
import AuthData          // 앱 조립 지점이라 Data를 직접 import 한다 (아키텍처 규칙 2의 예외)
import CHALLANetwork
import Keychain

/// 데모 진입 화면 — 실서버 / Mock 두 구성으로 로그인 화면을 띄운다.
struct DemoRootView: View {

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("실서버(AuthData) 로그인") { liveLogin }
                NavigationLink("Mock 로그인 (신규 유저)") { mockLogin }
            }
            .navigationTitle("로그인 데모")
        }
    }

    // 구성 1: 실제 구체 어댑터를 직접 조립해 주입 — 카카오/애플 SDK · 실서버 · Keychain까지 실동작.
    @MainActor private var liveLogin: some View {
        LoginView(
            store: Store(initialState: LoginFeature.State()) {
                LoginFeature()._printChanges()   // delegate 액션 로그로 성공 확인
            } withDependencies: {
                // TODO: [App/DIContainer 도입 시 이관] 데모앱이 임시로 떠맡은 Store별 override다.
                //       실제 App에서는 앱 시작 시 DependencyAssembly가 prepareDependencies로 1회 주입한다.
                $0.loginUseCase = CompositionRoot.makeLoginUseCase()
            }
        )
    }

    // 구성 2: Mock 주입 — SDK/서버 없이 화면·리듀서 흐름만 검증.
    @MainActor private var mockLogin: some View {
        LoginView(
            store: Store(initialState: LoginFeature.State()) {
                LoginFeature()._printChanges()
            } withDependencies: {
                $0.loginUseCase = LoginUseCase(run: { _ in
                    try await Task.sleep(for: .seconds(1))   // 로딩 스피너 확인용 지연
                    return LoginResult(isNewUser: true)
                })
            }
        )
    }
}

// MARK: - 합성 루트 (임시)
//
// TODO: [App/DIContainer 도입 시 이관] 이 CompositionRoot 전체가 데모앱이 임시로 떠맡은 합성 루트다.
//       Projects/App·Projects/DIContainer가 생기면:
//         1. 아래 makeLoginUseCase 본문(구체 어댑터 조립)을 `DIContainer/LiveDependency.register(_:)`로 그대로 옮긴다.
//         2. `App/DependencyAssembly`가 앱 시작 시 `prepareDependencies { LiveDependency.register(&$0) }`로 1회 주입한다.
//         3. 이 CompositionRoot 타입과 위 liveLogin의 override를 제거한다
//            (데모는 Mock 구성만 남기거나, LiveDependency.register를 재사용).
//       참고: docs/ARCHITECTURE.md — App/DependencyAssembly · DIContainer/LiveDependency
private enum CompositionRoot {

    /// 실서버용 `LoginUseCase`를 구체 어댑터로 직접 조립한다 (오케스트레이션은 Domain의 `LoginUseCase.live`가 소유).
    ///
    /// ⚠️ 토큰 흐름 공유 배선: `tokenStore` **한 인스턴스**를
    ///    - `AuthInterceptor`(요청마다 액세스 토큰을 읽음)와
    ///    - `LoginUseCase.live`(로그인 성공 시 토큰을 저장)
    ///    양쪽에 같은 것으로 넘겨야 저장→조회가 연결된다. 합성 루트가 책임지는 유일한 배선 지식이다.
    ///
    /// `@MainActor`: 애플 소셜 서비스가 메인 컨텍스트에서 생성되므로 (Store 생성도 뷰 컨텍스트라 문제없음).
    @MainActor
    static func makeLoginUseCase(session: URLSession = .shared) -> LoginUseCase {
        let keychain = KeychainStore(service: "com.challa.auth")
        let tokenStore = KeychainTokenStore(keychain: keychain)
        let client = DefaultHTTPClient(
            session: session,
            interceptors: [
                AuthInterceptor(tokenProvider: tokenStore),   // login/refresh는 .none이라 미부착
                LoggingInterceptor(level: .basic)
            ]
        )
        let repository = DefaultAuthRepository(client: client)
        let social = DefaultSocialLoginService()
        return LoginUseCase.live(
            social: social,
            repository: repository,
            tokenStore: tokenStore
        )
    }
}
