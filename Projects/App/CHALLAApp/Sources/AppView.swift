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
import UIKit

/// 앱 최상위 View. `AppFeature.State`에 따라 보여줄 화면을 고른다.
///
/// `SettingView`가 자기 `NavigationStack`을 소유하므로 여기서 push하지 않고 화면을 교체한다 —
/// 중첩 `NavigationStack`은 동작이 깨진다 (`SettingFeature/MODULE.md`).
/// 앱에 `NavigationStack`이 하나도 없어 이 방식으로 충돌이 생기지 않는다.
///
/// 대신 전환 애니메이션은 `ScreenTransitionCoordinator`가 화면 관계에 맞춰 재현한다 —
/// 네비게이션 관계면 push/pop 슬라이드, 카메라는 모달처럼 아래에서 위로, 나머지는 페이드.
public struct AppView: View {

    @Bindable private var store: StoreOf<AppFeature>

    /// 화면 전이 방향(push/pop/present…)을 modifier가 애니메이션 시점에 읽을 수 있게 보관한다.
    @State private var transitionCoordinator = ScreenTransitionCoordinator()

    /// 진행 중인 엣지 스와이프 pop. 시작한 화면 ID를 함께 들어, pop이 끝나 화면이 바뀌면 즉시 무효가 된다.
    @State private var popDragScreenID: AppFeature.State.ScreenID?
    @State private var popDragOffset: CGFloat = 0
    @State private var snapshotTask: Task<Void, Never>?
    /// 스와이프 pop 완료 직후 잠깐 덮어 두는 직전 스냅샷 (nil이면 없음).
    @State private var popSwapCover: UIImage?

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
        // 전이(from→to)는 새 화면이 삽입되기 전에 기록돼야 하므로 body 평가 시점에 갱신한다.
        // ViewBuilder 안에서는 선언만 허용돼 `let _ =` 형태를 유지해야 한다 (두 린터 모두 예외 처리).
        // swiftformat:disable:next redundantLet
        let _ = transitionCoordinator.update(to: store.screenID) // swiftlint:disable:this redundant_discardable_let
        ZStack {
            popSnapshotUnderlay
            currentScreen
                .offset(x: popDragScreenID == store.screenID ? popDragOffset : 0)
            // 스와이프 pop 직후 새로 만든 화면이 비동기 이미지를 그리는 동안 직전 스냅샷을
            // 잠깐 덮어 두고 페이드로 걷는다 — 사진 자리가 비었다 채워지는 깜빡임을 가린다.
            if let cover = popSwapCover {
                Color.clear
                    .overlay { Image(uiImage: cover).resizable() }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .zIndex(10)
                    .transition(.opacity)
            }
        }
        // safe area까지 더해 윈도우 전체 크기를 기록한다 — 세로 이동(카메라 present/dismiss)이
        // safe area 안쪽 높이만큼만 움직이면, safe area를 무시하는 배경·테두리의 아랫부분이
        // 화면 하단에 걸린 채 남는다.
        .onGeometryChange(for: CGSize.self) { proxy in
            CGSize(
                width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
                height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            )
        } action: { size in
            transitionCoordinator.containerSize = size
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.safeAreaInsets.top
        } action: { inset in
            transitionCoordinator.topInset = inset
        }
        .overlay(alignment: .leading) {
            if canPopInteractively {
                // UIKit의 엣지 pop처럼 왼쪽 가장자리 좁은 띠만 제스처가 차지한다.
                Color.clear
                    .frame(width: 20)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .highPriorityGesture(popDragGesture)
                    .accessibilityHidden(true)
            }
        }
        .environment(\.challaTheme, CHALLATheme(accent: theme.themeColor))
        // `.animation(_:value:)`는 전환(뷰 삽입·제거)에는 적용되지 않아 전환이 기본 스프링으로
        // 돌았다(재현 앱 실측 — linear 2초를 지정해도 무시됨). 트랜잭션을 직접 덮어써야
        // 지정한 곡선이 전환에 실린다. 제스처가 끝낸 pop은 nil이 실려 즉시 반영된다.
        .transaction(value: store.screenID) { transaction in
            transaction.animation = transitionCoordinator.animation
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
        .onChange(of: store.screenID) { _, newID in
            AccessibilityNotification.ScreenChanged().post()
            scheduleSnapshotCapture(of: newID)
        }
    }

    /// 전환이 끝나 화면이 정지한 뒤 pop 밑그림용 스냅샷을 찍는다.
    /// 전환 도중에 찍으면 반쯤 렌더된 합성 이미지가 남는다 — 그 이미지가 pop 때 좌측 여백처럼 보인다.
    private func scheduleSnapshotCapture(of id: AppFeature.State.ScreenID) {
        guard ScreenTransitionCoordinator.isPopParent(id) else { return }
        snapshotTask?.cancel()
        snapshotTask = Task {
            try? await Task.sleep(for: .seconds(0.7))
            guard !Task.isCancelled, store.screenID == id else { return }
            transitionCoordinator.captureSnapshot(for: id)
        }
    }

    private var currentScreen: some View {
        Group {
            switch store.state {
            case .launching:
                SplashView()
                    .screenLayer(.launching, coordinator: transitionCoordinator)

            case .login:
                if let loginStore = store.scope(state: \.login, action: \.login) {
                    LoginView(store: loginStore)
                        .screenLayer(.login, coordinator: transitionCoordinator)
                }

            case .profileSetup:
                if let profileStore = store.scope(state: \.profileSetup, action: \.profileSetup) {
                    ProfileSetupView(store: profileStore)
                        .screenLayer(.profileSetup, coordinator: transitionCoordinator)
                }

            case .home:
                if let homeStore = store.scope(state: \.home?.home, action: \.home) {
                    HomeView(store: homeStore)
                        .screenLayer(.home, coordinator: transitionCoordinator)
                }

            case .roomDetail:
                if let roomDetailStore = store.scope(state: \.roomDetail?.roomDetail, action: \.roomDetail) {
                    RoomDetailView(store: roomDetailStore)
                        .screenLayer(.roomDetail, coordinator: transitionCoordinator)
                }

            case .roomSettings:
                if let settingsStore = store.scope(state: \.roomSettings?.settings, action: \.roomSettings) {
                    RoomSettingsView(store: settingsStore)
                        .screenLayer(.roomSettings, coordinator: transitionCoordinator)
                }

            case .photoDetail:
                if let photoDetailStore = store.scope(state: \.photoDetail?.photoDetail, action: \.photoDetail) {
                    PhotoDetailView(store: photoDetailStore)
                        .screenLayer(.photoDetail, coordinator: transitionCoordinator)
                }

            case .chat:
                if let chatStore = store.scope(state: \.chat?.chat, action: \.chat) {
                    ChatRoomView(store: chatStore)
                        .screenLayer(.chat, coordinator: transitionCoordinator)
                }

            case .setting:
                if let settingStore = store.scope(state: \.setting?.setting, action: \.setting) {
                    SettingView(store: settingStore)
                        .screenLayer(.setting, coordinator: transitionCoordinator)
                }

            case .profileEdit:
                if let editStore = store.scope(state: \.profileEdit?.edit, action: \.profileEdit) {
                    ProfileSetupView(store: editStore)
                        .screenLayer(.profileEdit, coordinator: transitionCoordinator)
                }

            case .camera:
                if let cameraStore = store.scope(state: \.camera?.live.camera, action: \.camera.camera) {
                    CameraView(store: cameraStore) {
                        LiveCameraPreview(session: cameraSession, store: cameraStore)
                    }
                    .screenLayer(.camera, coordinator: transitionCoordinator)
                }

            case .forceUpdate:
                // 알럿 뒤 배경. 강제 업데이트는 실행 직후 판정이라 스플래시가 그대로 남는 게 자연스럽다.
                SplashView()
            }
        }
    }

    /// 인터랙티브 pop 중 현재 화면 밑에 깔리는 부모 화면 스냅샷 — push/pop의 30% 밀림·디밍을 따라간다.
    @ViewBuilder
    private var popSnapshotUnderlay: some View {
        if popDragScreenID == store.screenID, popDragOffset > 0,
           let snapshot = transitionCoordinator.snapshotBehind(store.screenID) {
            let width = transitionCoordinator.containerSize.width
            let progress = width > 0 ? min(1, popDragOffset / width) : 0
            // 스냅샷은 윈도우 전체 크기다. ignoresSafeArea는 반드시 overlay들 뒤(맨 바깥)에
            // 둬야 한다 — 안쪽에 두면 overlay가 safe area 확장 전 프레임에 붙어 이미지가
            // 상단 safe area만큼 아래로 밀려 그려진다 (상·하단이 잘려 보이던 원인).
            Color.clear
                .overlay { Image(uiImage: snapshot).resizable() }
                .overlay {
                    Color.black
                        .opacity(0.1 * (1 - progress))
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea()
                .offset(x: -(1 - progress) * width * 0.3)
                .accessibilityHidden(true)
        }
    }

    /// 설정 화면은 내부 스택이 비어 있을 때만 — push된 상태면 자기 `NavigationStack`의
    /// 네이티브 pop 제스처가 받아야 한다.
    private var canPopInteractively: Bool {
        if case let .setting(screen) = store.state, !screen.setting.path.isEmpty {
            return false
        }
        return transitionCoordinator.snapshotBehind(store.screenID) != nil
    }

    private var popDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard value.translation.width > 0 else { return }
                popDragScreenID = store.screenID
                popDragOffset = value.translation.width
            }
            .onEnded { value in
                let width = transitionCoordinator.containerSize.width
                guard popDragScreenID == store.screenID, width > 0 else {
                    popDragScreenID = nil
                    popDragOffset = 0
                    return
                }
                if value.predictedEndTranslation.width > width * 0.5 {
                    withAnimation(ScreenTransitionCoordinator.transitionAnimation) {
                        popDragOffset = width
                    } completion: {
                        // 제스처가 이미 화면을 끝까지 밀어냈다 — 상태 반영이 다시 움직이면 안 된다.
                        transitionCoordinator.completeInteractivePop()
                        popSwapCover = transitionCoordinator.snapshotBehind(store.screenID)
                        store.send(.popGestureCompleted)
                        popDragScreenID = nil
                        popDragOffset = 0
                        Task {
                            try? await Task.sleep(for: .milliseconds(120))
                            withAnimation(.linear(duration: 0.15)) { popSwapCover = nil }
                        }
                    }
                } else {
                    withAnimation(ScreenTransitionCoordinator.transitionAnimation) {
                        popDragOffset = 0
                    } completion: {
                        popDragScreenID = nil
                    }
                }
            }
    }
}

// TODO: 임의 작성 문구 — 기획 확정 시 교체할 것.
private enum ForceUpdateCopy {
    static let title = "업데이트가 필요해요"
    static let message = "지금 버전에서는 서비스를 이용할 수 없어요.\nApp Store에서 최신 버전으로 업데이트해 주세요."
    static let confirm = "업데이트하러 가기"
}
