import ComposableArchitecture
import HomeFeature
import LoginFeature
import ProfileSetupFeature
import RoomDetailFeature
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

            case .roomDetail:
                if let roomDetailStore = store.scope(state: \.roomDetail?.roomDetail, action: \.roomDetail) {
                    RoomDetailView(store: roomDetailStore)
                }

            case .setting:
                if let settingStore = store.scope(state: \.setting?.setting, action: \.setting) {
                    SettingView(store: settingStore)
                }

            case .profileEdit:
                if let editStore = store.scope(state: \.profileEdit?.edit, action: \.profileEdit) {
                    ProfileSetupView(store: editStore)
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
