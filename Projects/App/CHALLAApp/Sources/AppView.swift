import CameraFeature
import CameraSession
import CHALLADesignSystem
import ChatRoomFeature
import ComposableArchitecture
import HomeFeature
import LoginFeature
import PhotoDetailFeature
import ProfileSetupFeature
import RoomDetailFeature
import SettingDomain
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

    /// 사용자가 고른 테마. 앱에서 여기서만 읽어 Environment로 내려보낸다.
    /// 설정 화면이 값을 바꾸면 같은 저장소를 보고 있어 화면 전체가 함께 다시 그려진다.
    ///
    /// `CHALLAApp`이 아니라 이 뷰가 읽는다 — `App`의 저장 프로퍼티는 `init` 본문보다 먼저
    /// 초기화돼서, 거기 두면 `prepareDependencies`가 깔리기 전에 저장소를 구독한다.
    @SharedReader(.appTheme) private var theme: AppTheme

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

            case .photoDetail:
                if let photoDetailStore = store.scope(state: \.photoDetail?.photoDetail, action: \.photoDetail) {
                    PhotoDetailView(store: photoDetailStore)
                }

            case .chat:
                if let chatStore = store.scope(state: \.chat?.chat, action: \.chat) {
                    ChatRoomView(store: chatStore)
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

            case .forceUpdate:
                // 알럿 뒤 배경. 강제 업데이트는 실행 직후 판정이라 스플래시가 그대로 남는 게 자연스럽다.
                LaunchingView()
            }
        }
        .environment(\.challaTheme, CHALLATheme(accent: theme.themeColor))
        .animation(.snappy, value: store.screenID)
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
