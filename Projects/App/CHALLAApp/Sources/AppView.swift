import ComposableArchitecture
import HomeFeature
import LoginFeature
import ProfileSetupFeature
import SettingFeature
import SwiftUI

/// 앱 최상위 View. `AppFeature.State`에 따라 보여줄 화면을 고른다.
///
/// `SettingView`가 자기 `NavigationStack`을 소유하므로 여기서 push하지 않고 화면을 교체한다 —
/// 중첩 `NavigationStack`은 동작이 깨진다 (`SettingFeature/MODULE.md`).
/// 앱에 `NavigationStack`이 하나도 없어 이 방식으로 충돌이 생기지 않는다.
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
                if let homeStore = store.scope(state: \.home?.home, action: \.home) {
                    HomeView(store: homeStore)
                }

            case .setting:
                if let settingStore = store.scope(state: \.setting?.setting, action: \.setting) {
                    SettingView(store: settingStore)
                }

            case .profileEdit:
                if let editStore = store.scope(state: \.profileEdit?.edit, action: \.profileEdit) {
                    ProfileSetupView(store: editStore)
                }

            case .forceUpdate:
                // 알럿 뒤 배경. 강제 업데이트는 실행 직후 판정이라 스플래시가 그대로 남는 게 자연스럽다.
                LaunchingView()
            }
        }
        // 이 알럿에는 "닫힘" 상태가 없다. 표시 여부가 화면 상태에서 100% 파생되므로
        // `@Presents`(optional 저장)는 파생값 저장 금지 원칙에 어긋나 `.constant` 바인딩을 쓴다.
        .alert(
            Text(ForceUpdateCopy.title),
            isPresented: .constant(store.screenID == .forceUpdate),
            actions: {
                Button(ForceUpdateCopy.confirm) { store.send(.forceUpdateConfirmTapped) }
            },
            message: { Text(ForceUpdateCopy.message) }
        )
        .task { store.send(.task) }
        // 네비게이션 없이 뷰를 갈아끼우므로 VoiceOver는 화면이 바뀐 걸 스스로 알지 못한다.
        .onChange(of: store.screenID) {
            AccessibilityNotification.ScreenChanged().post()
        }
    }
}

// TODO: 임의 작성 문구 — 기획 확정 시 교체할 것.
private enum ForceUpdateCopy {
    static let title = "업데이트가 필요해요"
    static let message = "지금 버전에서는 서비스를 이용할 수 없어요.\nApp Store에서 최신 버전으로 업데이트해 주세요."
    static let confirm = "업데이트하러 가기"
}
