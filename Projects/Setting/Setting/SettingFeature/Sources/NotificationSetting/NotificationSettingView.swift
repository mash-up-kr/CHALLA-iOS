import CHALLADesignSystem
import ComposableArchitecture
import SettingDomain
import SwiftUI

/// 알림 설정 화면 — 권한 배너(권한이 꺼져 있을 때만) + 서비스 알림 토글.
@ViewAction(for: NotificationSettingFeature.self)
public struct NotificationSettingView: View {

    /// 설정 앱에서 권한을 바꾸고 돌아오는 경로를 잡는다 — 포그라운드 복귀 때 다시 조회한다.
    @Environment(\.scenePhase) private var scenePhase

    public let store: StoreOf<NotificationSettingFeature>

    public init(store: StoreOf<NotificationSettingFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            CHALLATopNavigation.sub(
                title: "알림",
                leading: .icon(.caretLeft, accessibilityLabel: "뒤로 가기") {
                    send(.backButtonTapped)
                }
            )

            ScrollView {
                VStack(spacing: SettingLayout.cardSpacing) {
                    if store.showsPermissionBanner {
                        permissionBanner
                    }
                    serviceNotificationCard
                }
                .padding(.horizontal, SettingLayout.horizontalPadding)
                .padding(.top, SettingLayout.contentTopPadding)
                .padding(.bottom, SettingLayout.bottomPadding)
            }
            // 내용이 화면보다 짧을 때 이유 없이 튀지 않게 한다.
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dynamicTypeSize(...SettingLayout.maxDynamicTypeSize)
        .background(CHALLAColor.Background.surface)
        .onAppear { send(.onAppear) }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            send(.sceneBecameActive)
        }
    }

    // MARK: - 카드

    /// 시스템 알림 권한이 꺼져 있을 때만 뜬다. 누르면 설정 앱으로 나간다.
    private var permissionBanner: some View {
        CHALLAListSection {
            CHALLAListRow(
                "휴대폰의 앱 알림이 꺼져있어요.",
                icon: .error,
                iconColor: CHALLAColor.Status.destructive
            ) {
                send(.permissionBannerTapped)
            }
            // 앱 밖으로 나간다는 사실은 문구만으로 전달되지 않는다.
            .accessibilityHint("iOS 설정 앱의 알림 화면을 엽니다")
        }
    }

    private var serviceNotificationCard: some View {
        CHALLAListSection {
            CHALLAListRow(
                "서비스 알림",
                description: "인화 대기, 인화 완료 등",
                isOn: isServiceNotificationEnabled
            )
        }
    }

    // MARK: - 바인딩

    /// `CHALLAListRow`의 토글이 `Binding<Bool>`을 요구한다.
    /// 쓰기는 액션으로 흘려보낸다 — 상태 변경이 전부 리듀서 안에 남는다.
    private var isServiceNotificationEnabled: Binding<Bool> {
        Binding(
            get: { store.isServiceNotificationEnabled },
            set: { send(.serviceNotificationToggled($0)) }
        )
    }
}

#Preview {
    NotificationSettingView(
        store: Store(initialState: NotificationSettingFeature.State()) {
            NotificationSettingFeature()
        }
    )
}
