import CameraFeature
import CameraSession
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
///
/// 카메라만 아래에서 올라오고 내려가며 교체된다 — 시트처럼 덮었다 걷히는 화면이기 때문이다.
/// 나머지 화면은 페이드로 바뀌므로, 카메라가 올라오는 동안 이전 화면이 뒤에서 흐려지며 비친다.
public struct AppView: View {

    @Bindable private var store: StoreOf<AppFeature>

    /// 실기기 카메라 세션. 리듀서(`LiveCameraFeature`)와 프리뷰가 같은 인스턴스를 봐야 하므로
    /// `@Dependency`로 공유되는 live 값을 뷰에서도 그대로 가져와 프리뷰에 넘긴다.
    @Dependency(\.cameraSession) private var cameraSession

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            switch store.state {
            case .launching:
                LaunchingView()
                    .transition(.opacity)

            case .login:
                if let loginStore = store.scope(state: \.login, action: \.login) {
                    LoginView(store: loginStore)
                        .transition(.opacity)
                }

            case .profileSetup:
                if let profileStore = store.scope(state: \.profileSetup, action: \.profileSetup) {
                    ProfileSetupView(store: profileStore)
                        .transition(.opacity)
                }

            case .home:
                if let homeStore = store.scope(state: \.home?.home, action: \.home) {
                    HomeView(store: homeStore)
                        .transition(.opacity)
                }

            case .roomDetail:
                if let roomDetailStore = store.scope(state: \.roomDetail?.roomDetail, action: \.roomDetail) {
                    RoomDetailView(store: roomDetailStore)
                }

            case .roomSettings:
                if let settingsStore = store.scope(state: \.roomSettings?.settings, action: \.roomSettings) {
                    RoomSettingsView(store: settingsStore)
                }

            case .setting:
                if let settingStore = store.scope(state: \.setting?.setting, action: \.setting) {
                    SettingView(store: settingStore)
                        .transition(.opacity)
                }

            case .profileEdit:
                if let editStore = store.scope(state: \.profileEdit?.edit, action: \.profileEdit) {
                    ProfileSetupView(store: editStore)
                        .transition(.opacity)
                }

            case .camera:
                if let cameraStore = store.scope(state: \.camera?.live.camera, action: \.camera.camera) {
                    CameraView(store: cameraStore) {
                        LiveCameraPreview(session: cameraSession, store: cameraStore)
                    }
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .animation(.snappy, value: store.screenID)
        .task { store.send(.task) }
        // 네비게이션 없이 뷰를 갈아끼우므로 VoiceOver는 화면이 바뀐 걸 스스로 알지 못한다.
        .onChange(of: store.screenID) {
            AccessibilityNotification.ScreenChanged().post()
        }
    }
}
