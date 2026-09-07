import CHALLADesignSystem
import ComposableArchitecture
import SwiftUI

/// 설정 화면 — 프로필 헤더 + 설정 항목 카드 3장.
///
/// 하위 화면(테마·알림·계정 관리)의 `NavigationStack`을 여기서 소유한다.
/// 따라서 **App은 이 뷰를 다른 `NavigationStack` 안으로 push 하면 안 된다** —
/// 중첩 `NavigationStack`은 SwiftUI에서 동작이 깨진다 (`MODULE.md` 참고).
@ViewAction(for: SettingFeature.self)
public struct SettingView: View {

    @Bindable public var store: StoreOf<SettingFeature>

    public init(store: StoreOf<SettingFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            settingRoot
        } destination: { store in
            Group {
                switch store.case {
                case let .theme(store):
                    ThemeView(store: store)
                case let .notification(store):
                    NotificationSettingView(store: store)
                case let .account(store):
                    AccountView(store: store)
                }
            }
            // 세 화면 모두 `CHALLATopNavigation`을 직접 그리므로 시스템 바를 숨긴다.
            // 부작용으로 시스템 스와이프 백 제스처가 사라진다 — 뒤로가기는 CaretLeft 버튼으로만 한다
            // (`MODULE.md`의 "시안 대비 알려진 차이").
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - 루트

    private var settingRoot: some View {
        VStack(spacing: 0) {
            // 시안에 타이틀이 없다 — 뒤로가기 버튼만 있는 sub 바.
            CHALLATopNavigation.sub(
                title: "",
                leading: .icon(.caretLeft, accessibilityLabel: "뒤로 가기") {
                    send(.backButtonTapped)
                }
            )

            ScrollView {
                // 헤더는 화면 폭을 그대로 쓰고(자체 여백 28/20), 카드만 좌우 16으로 들여쓴다.
                // 헤더와 첫 카드 사이 간격은 0이다 — 헤더 블록(100)이 끝나는 지점에서 카드가 바로 시작한다.
                VStack(spacing: 0) {
                    SettingProfileHeader(profile: store.profile) {
                        send(.editProfileButtonTapped)
                    }

                    VStack(spacing: SettingLayout.cardSpacing) {
                        appSettingCard
                        accountCard
                        feedbackCard
                    }
                    .padding(.horizontal, SettingLayout.horizontalPadding)
                }
                .padding(.bottom, SettingLayout.bottomPadding)
            }
            // 내용이 화면보다 짧을 때 이유 없이 튀지 않게 한다.
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dynamicTypeSize(...SettingLayout.maxDynamicTypeSize)
        .background(CHALLAColor.Background.surface)
        // 루트도 자기 탑바를 그린다 — 시스템 바를 남겨두면 그 높이만큼 아래로 밀린다.
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { send(.onAppear) }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - 카드

    private var appSettingCard: some View {
        CHALLAListSection("앱 설정") {
            CHALLAListRow(
                "테마",
                icon: .palette,
                iconColor: SettingLayout.rowIconColor,
                accessory: .arrow(value: store.themeDisplayName)
            ) {
                send(.themeRowTapped)
            }
            CHALLAListRow(
                "알림",
                icon: .bellSimple,
                iconColor: SettingLayout.rowIconColor
            ) {
                send(.notificationRowTapped)
            }
        }
    }

    private var accountCard: some View {
        CHALLAListSection("계정") {
            CHALLAListRow(
                "계정 관리",
                icon: .profile,
                iconColor: SettingLayout.rowIconColor
            ) {
                send(.accountRowTapped)
            }
        }
    }

    private var feedbackCard: some View {
        CHALLAListSection("피드백") {
            // 찰나 응원하기 — App Store 리뷰 주소가 없어 눌러도 아무 일이 없다. 주소가 정해질 때까지 숨긴다.
            // CHALLAListRow(
            //     "찰나 응원하기",
            //     icon: .carrot,
            //     iconColor: SettingLayout.rowIconColor
            // ) {
            //     send(.supportRowTapped)
            // }
            CHALLAListRow(
                "피드백 보내기",
                icon: .chatTeardropDots,
                iconColor: SettingLayout.rowIconColor
            ) {
                send(.feedbackRowTapped)
            }
        }
    }
}
