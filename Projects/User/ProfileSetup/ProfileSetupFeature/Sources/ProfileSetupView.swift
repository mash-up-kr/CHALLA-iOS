import CHALLADesignSystem
import ComposableArchitecture
import PhotosUI
import SwiftUI
import UserDomain

/// 프로필 설정 화면 (Zeplin CreateProfile).
///
/// 배경 → (환영 시) 글로우 → 내비 + 폼 순의 ZStack에 토스트를 상단 overlay로 얹는다.
/// 뷰는 상태 렌더링과 `send(...)` 전달만 한다 — 입력 정리·토스트·CTA 판단은 전부 리듀서 책임이다.
@ViewAction(for: ProfileSetupFeature.self)
public struct ProfileSetupView: View {

    @Bindable public var store: StoreOf<ProfileSetupFeature>
    @FocusState private var isNicknameFocused: Bool

    public init(store: StoreOf<ProfileSetupFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            CHALLAColor.Background.surface
                .ignoresSafeArea()

            if store.phase == .welcome {
                WelcomeGlowView()
            }

            VStack(spacing: 0) {
                CHALLATopNavigation.sub(title: "프로필 설정")
                ProfileFormView(
                    headline: headline,
                    avatar: avatar,
                    showsCameraBadge: store.showsCameraBadge,
                    nickname: $store.nickname,
                    focus: $isNicknameFocused,
                    fieldMode: fieldMode,
                    cta: cta,
                    onAvatarTap: { send(.profileImageButtonTapped) }
                )
            }
        }
        .overlay(alignment: .top) { toastLayer }
        .challaDrawer(isPresented: $store.isPhotoMenuPresented) { photoMenuDrawer }
        // photoLibrary를 지정하면 앱 프로세스 안에서 라이브러리를 읽는다 — 앞단의 권한 요청이 여기에 걸린다.
        .photosPicker(
            isPresented: $store.isPhotoPickerPresented,
            selection: $store.photoPickerItem,
            matching: .images,
            photoLibrary: .shared()
        )
        // 컨테이너에 붙여도 자식 TextField에 전파된다.
        .task { send(.task) }
        .onSubmit { send(.nicknameSubmitted) }
        .submitLabel(.done)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .contentShape(Rectangle())
        .onTapGesture { send(.backgroundTapped) }
        .bind($store.isNicknameFocused, to: $isNicknameFocused)
        .onChange(of: store.phase) { _, newPhase in
            if newPhase == .welcome {
                AccessibilityNotification.ScreenChanged().post()
            }
        }
    }

    @ViewBuilder
    private var toastLayer: some View {
        if let toast = store.toast {
            CHALLAToast(toast.message, icon: .error, variant: .negative)
                .padding(.top, Metric.toastTopSpacing)
        }
    }

    /// 사진 메뉴 드로어 (UploadImage 시안). 등록된 사진이 없으면 삭제 버튼은 내지 않는다.
    private var photoMenuDrawer: some View {
        CHALLADrawer(
            header: .handle,
            actions: photoMenuActions,
            footerAction: CHALLADrawerAction("닫기") { send(.photoMenuDismissed) }
        )
    }

    private var photoMenuActions: [CHALLADrawerAction] {
        var actions = [
            CHALLADrawerAction("앨범에서 선택", variant: .neutral) { send(.albumSelectTapped) }
        ]
        if store.canRemovePhoto {
            actions.append(
                CHALLADrawerAction("프로필 사진 삭제", variant: .neutral, role: .destructive) {
                    send(.photoRemoveTapped)
                }
            )
        }
        return actions
    }

    // MARK: - store → 뷰 파라미터 매핑

    /// 문구는 뷰가 소유한다 — State에는 phase·데이터만 둔다 (토스트 문구만 예외).
    private var headline: ProfileFormHeadline {
        if store.phase == .welcome {
            ProfileFormHeadline(highlighted: store.nickname, text: "만나서 반가워요!")
        } else {
            ProfileFormHeadline(highlighted: nil, text: "프로필과 닉네임을\n설정해 주세요")
        }
    }

    private var avatar: ProfileAvatarSource {
        store.imageData.map(ProfileAvatarSource.local) ?? .placeholder
    }

    private var fieldMode: ProfileNicknameFieldMode {
        guard store.isFieldEditable else { return .readOnly }
        return store.nicknameViolation != nil ? .invalid : .editable
    }

    private var cta: ProfileFormCTA? {
        guard store.isCTAVisible else { return nil }
        return ProfileFormCTA(
            title: "시작하기",
            isEnabled: store.isCTAEnabled,
            isLoading: store.isCTALoading
        ) {
            send(.startButtonTapped)
        }
    }
}

// MARK: - Zeplin 실측값

private enum Metric {
    /// 토스트 상단 y=114(절대) − 상태바 44 = 세이프에어리어 기준 70 (내비 바로 아래).
    static let toastTopSpacing: CGFloat = 70
}

// MARK: - Preview

#Preview("초기") {
    ProfileSetupView(
        store: Store(initialState: ProfileSetupFeature.State()) {
            ProfileSetupFeature()
        }
    )
}

#Preview("입력 완료") {
    ProfileSetupView(
        store: Store(initialState: ProfileSetupFeature.State(nickname: "나는야멋쟁이토마토")) {
            ProfileSetupFeature()
        }
    )
}

#Preview("오류 토스트") {
    let violation = NicknameRule.Violation.tooLong(limit: NicknameRule.maxLength)
    // 빨간 테두리·CTA 비활성은 11자라는 값에서 파생된다.
    var state = ProfileSetupFeature.State(nickname: "나는야멋쟁이토마토임다")
    state.toast = .init(message: violation.userMessage)
    return ProfileSetupView(
        store: Store(initialState: state) {
            ProfileSetupFeature()
        }
    )
}

#Preview("사진 메뉴 — 사진 없음") {
    var state = ProfileSetupFeature.State(nickname: "나는야멋쟁이토마토")
    state.isPhotoMenuPresented = true
    return ProfileSetupView(
        store: Store(initialState: state) {
            ProfileSetupFeature()
        }
    )
}

#Preview("제출 중") {
    var state = ProfileSetupFeature.State(nickname: "나는야멋쟁이토마토")
    state.phase = .submitting
    return ProfileSetupView(
        store: Store(initialState: state) {
            ProfileSetupFeature()
        }
    )
}

#Preview("환영") {
    var state = ProfileSetupFeature.State(nickname: "나는야멋쟁이토마토")
    state.phase = .welcome
    state.savedProfile = UserProfile(id: 1, nickname: "나는야멋쟁이토마토")
    return ProfileSetupView(
        store: Store(initialState: state) {
            ProfileSetupFeature()
        }
    )
}
