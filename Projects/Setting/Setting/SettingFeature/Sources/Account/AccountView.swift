import CHALLADesignSystem
import ComposableArchitecture
import SettingDomain
import SwiftUI

/// 계정 관리 화면 — 프로필 요약 + 로그아웃 행 + 하단 `탈퇴하기`.
///
/// 로그아웃·탈퇴는 되돌리기 어려워 확인 드로어를 한 번 거친다.
/// 드로어는 **모디파이어 하나**로 띄우고 내용만 `store.drawer`로 고른다 —
/// 두 개를 걸면 A를 내리는 애니메이션과 B를 올리는 애니메이션이 겹친다.
@ViewAction(for: AccountFeature.self)
public struct AccountView: View {

    @Bindable public var store: StoreOf<AccountFeature>

    public init(store: StoreOf<AccountFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            CHALLATopNavigation.sub(
                title: "계정 관리",
                leading: .icon(.caretLeft, accessibilityLabel: "뒤로 가기") {
                    send(.backButtonTapped)
                }
            )

            ScrollView {
                VStack(spacing: 0) {
                    AccountProfileSummary(profile: store.profile)
                        .padding(.top, SettingLayout.contentTopPadding)

                    accountCard
                        .padding(.top, Metric.profileToCardSpacing)
                        .padding(.horizontal, SettingLayout.horizontalPadding)
                }
                .padding(.bottom, SettingLayout.bottomPadding)
            }
            // 내용이 화면보다 짧을 때 이유 없이 튀지 않게 한다.
            .scrollBounceBehavior(.basedOnSize)

            // 스크롤 영역 밖에 둔다 — 시안에서 이 버튼은 내용 길이와 무관하게
            // 안전 영역 맨 아래(y756, 높이 54)에 붙어 있다.
            withdrawButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dynamicTypeSize(...SettingLayout.maxDynamicTypeSize)
        .background(CHALLAColor.Background.surface)
        .alert($store.scope(state: \.alert, action: \.alert))
        .challaDrawer(
            isPresented: isDrawerPresented,
            allowsInteractiveDismiss: store.isDrawerDismissable
        ) {
            drawer
        }
    }

    // MARK: - 카드

    private var accountCard: some View {
        CHALLAListSection {
            CHALLAListRow(
                "로그아웃",
                icon: .signOut,
                iconColor: SettingLayout.rowIconColor
            ) {
                send(.signOutRowTapped)
            }
        }
    }

    /// 시안의 글자색은 흐린 회색(`Label.alternative`)인데 `transparent` variant는 `Label.normal`이다.
    /// `role: .destructive`는 빨강, `.disabled(true)`는 탭이 막혀 둘 다 대체가 되지 않는다.
    /// 약한 강조 글자색은 **DS 별도 이슈**로 남기고 지금은 variant 기본색으로 둔다
    /// (`MODULE.md`의 "시안 대비 알려진 차이").
    private var withdrawButton: some View {
        CHALLATextButton("탈퇴하기", variant: .transparent) {
            send(.deleteAccountButtonTapped)
        }
    }

    // MARK: - 드로어

    /// 떠 있는 드로어가 있는지. 내리는 쪽은 액션으로 위임한다 —
    /// 완료 드로어가 닫히는 경우에는 탈퇴 완료 처리가 함께 나가야 한다.
    private var isDrawerPresented: Binding<Bool> {
        Binding(
            get: { store.drawer != nil },
            set: { isPresented in
                guard !isPresented else { return }
                send(.drawerDismissed)
            }
        )
    }

    @ViewBuilder
    private var drawer: some View {
        switch store.drawer {
        case .signOutConfirmation:
            // TODO: 시안에 로그아웃 행 탭 이후가 없어 문구는 임의 작성본이다 — 확정 시 교체할 것.
            CHALLADrawer(
                header: .handle,
                actions: [
                    // 진행 중에는 비활성 — 드로어는 그대로 두고 버튼만 잠근다 (탈퇴와 같은 정책).
                    CHALLADrawerAction(
                        "로그아웃",
                        variant: .neutral,
                        role: .destructive,
                        isEnabled: !store.isProcessing
                    ) {
                        send(.signOutConfirmed)
                    }
                ],
                footerAction: CHALLADrawerAction("닫기", isEnabled: !store.isProcessing) {
                    send(.drawerDismissed)
                }
            ) {
                CHALLADrawerMessage(
                    "로그아웃 할까요?",
                    description: "다시 로그인하면 이어서 사용할 수 있어요"
                )
            }

        case .deleteConfirmation:
            CHALLADrawer(
                header: .handle,
                actions: [
                    // 진행 중에는 비활성 — 드로어는 그대로 두고 버튼만 잠근다.
                    CHALLADrawerAction("그래도 탈퇴하기", role: .destructive, isEnabled: !store.isProcessing) {
                        send(.deleteConfirmed)
                    }
                ],
                footerAction: CHALLADrawerAction("닫기", isEnabled: !store.isProcessing) {
                    send(.drawerDismissed)
                }
            ) {
                CHALLADrawerMessage(
                    "모든 기록이 사라져요",
                    description: "탈퇴 시 참여 중이던 방에서 나가져요"
                )
            }

        case .deleteCompleted:
            CHALLADrawer(
                header: .handle,
                actions: [
                    CHALLADrawerAction("확인") {
                        send(.deleteCompletionConfirmed)
                    }
                ]
            ) {
                CHALLADrawerMessage("회원 탈퇴가 정상적으로 완료 됐어요")
            }

        case .none:
            EmptyView()
        }
    }
}

// MARK: - Metric

private enum Metric {
    /// 이메일 아래에서 카드까지 — 시안 실측 24.
    static let profileToCardSpacing: CGFloat = 24
}

#Preview {
    AccountView(
        store: Store(
            initialState: AccountFeature.State(
                profile: SettingProfile(
                    nickname: "나는야멋쟁이토마토",
                    avatarURL: nil
                )
            )
        ) {
            AccountFeature()
        }
    )
}
