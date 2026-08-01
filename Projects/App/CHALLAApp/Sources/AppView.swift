import ComposableArchitecture
import LoginFeature
import SwiftUI

/// 앱 최상위 View. `AppFeature.State.phase`에 따라 보여줄 화면을 고른다.
///
/// - `.login` → `LoginView` (앱의 초기 화면)
/// - `.authenticated` → 로그인 성공 placeholder (프로필 설정/메인 모듈 생기면 교체)
public struct AppView: View {

    @Bindable private var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.phase {
            case .login:
                LoginView(store: store.scope(state: \.login, action: \.login))

            case let .authenticated(isNewUser):
                AuthenticatedPlaceholderView(isNewUser: isNewUser)
            }
        }
        // 네비게이션 없이 뷰를 갈아끼우므로 VoiceOver는 화면이 바뀐 걸 스스로 알지 못한다.
        .onChange(of: store.phase) {
            AccessibilityNotification.ScreenChanged().post()
        }
    }
}
