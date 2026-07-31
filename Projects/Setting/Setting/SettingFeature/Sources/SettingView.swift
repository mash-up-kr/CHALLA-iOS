import CHALLADesignSystem
import ComposableArchitecture
import SwiftUI

/// 설정 화면 — 프로필 헤더 + 설정 항목 카드 3장.
@ViewAction(for: SettingFeature.self)
public struct SettingView: View {

    @Bindable public var store: StoreOf<SettingFeature>

    public init(store: StoreOf<SettingFeature>) {
        self.store = store
    }

    public var body: some View {
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
                    SettingProfileHeader(profile: store.snapshot?.profile) {
                        send(.editProfileButtonTapped)
                    }

                    VStack(spacing: Metric.cardSpacing) {
                        appSettingCard
                        accountCard
                        feedbackCard
                    }
                    .padding(.horizontal, Metric.horizontalPadding)
                }
                .padding(.bottom, Metric.bottomPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CHALLAColor.Background.surface)
        .onAppear { send(.onAppear) }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - 카드

    private var appSettingCard: some View {
        CHALLAListSection("앱 설정") {
            // TODO: 값 글자가 항상 `CHALLAColor.defaultTheme`(yellow)로 그려진다 —
            // `CHALLAListRow`가 `themeColor`로 칠하는데 여기서 넘기지 않기 때문이다.
            // 지금은 저장된 테마가 늘 기본값(레몬에이드=yellow)이라 결과가 맞지만,
            // 테마 선택 화면이 생기면 어긋난다. `AppTheme` → `Primary` 매핑 6쌍이
            // 확정되면 `themeColor:`를 함께 넘길 것 (`AppTheme.swift` 주석 참고).
            CHALLAListRow(
                "테마",
                icon: .palette,
                iconColor: Metric.rowIconColor,
                accessory: .arrow(value: store.themeDisplayName)
            ) {
                send(.themeRowTapped)
            }
            CHALLAListRow(
                "알림",
                icon: .bellSimple,
                iconColor: Metric.rowIconColor
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
                iconColor: Metric.rowIconColor
            ) {
                send(.accountRowTapped)
            }
        }
    }

    private var feedbackCard: some View {
        CHALLAListSection("피드백") {
            CHALLAListRow(
                "찰나 응원하기",
                icon: .carrot,
                iconColor: Metric.rowIconColor
            ) {
                send(.supportRowTapped)
            }
            CHALLAListRow(
                "피드백 보내기",
                icon: .chatTeardropDots,
                iconColor: Metric.rowIconColor
            ) {
                send(.feedbackRowTapped)
            }
        }
    }
}

// MARK: - Metric

private enum Metric {
    /// 카드 사이 세로 간격 — 시안 실측 16.
    static let cardSpacing: CGFloat = 16
    /// 카드 좌우 여백 — 390 기준 카드 폭 358.
    static let horizontalPadding: CGFloat = 16
    static let bottomPadding: CGFloat = 24

    /// 행 leading 아이콘 색.
    ///
    /// Zeplin `List / Arrow` 컴포넌트 정의는 `Label.neutral`(#AEAFB4)인데
    /// 설정 화면 인스턴스는 `Label.alternative`(#74767B)를 쓴다. 시안 대조 검증이
    /// 화면 기준이라 화면을 따르고, 컴포넌트 기본값은 건드리지 않는다.
    /// TODO: 어느 쪽이 맞는지 디자이너 확정 필요.
    static let rowIconColor = CHALLAColor.Label.alternative
}
