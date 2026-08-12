import ComposableArchitecture
import HomeFeature
import LoginFeature
import ProfileSetupFeature
import SwiftUI

/// 앱 최상위 View. `AppFeature.State`에 따라 보여줄 화면을 고른다.
public struct AppView: View {

    @Bindable private var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            switch store.state {
            case .launching:
                LaunchingView()

            case .login:
                if let loginStore = store.scope(state: \.login, action: \.login) {
                    LoginView(store: loginStore)
                }

            case .profileSetup:
                if let profileStore = store.scope(state: \.profileSetup, action: \.profileSetup) {
                    ProfileSetupView(store: profileStore)
                }

            case .home:
                if let homeStore = store.scope(state: \.home, action: \.home) {
                    HomeView(store: homeStore)
                }
            }
        }
        .task { store.send(.task) }
        // 네비게이션 없이 뷰를 갈아끼우므로 VoiceOver는 화면이 바뀐 걸 스스로 알지 못한다.
        .onChange(of: store.screenID) {
            AccessibilityNotification.ScreenChanged().post()
        }
    }
}
