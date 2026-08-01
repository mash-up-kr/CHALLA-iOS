import CHALLADesignSystem
import ComposableArchitecture
import SettingDomain
import SwiftUI

/// 테마 선택 화면 — 여섯 개 중 하나에 체크가 찍힌 단일 선택 목록.
///
/// 고른 뒤에도 화면에 머문다 (`ThemeFeature` 주석 참고).
@ViewAction(for: ThemeFeature.self)
public struct ThemeView: View {

    public let store: StoreOf<ThemeFeature>

    public init(store: StoreOf<ThemeFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            CHALLATopNavigation.sub(
                title: "테마",
                leading: .icon(.caretLeft, accessibilityLabel: "뒤로 가기") {
                    send(.backButtonTapped)
                }
            )

            ScrollView {
                themeCard
                    .padding(.horizontal, SettingLayout.horizontalPadding)
                    .padding(.top, SettingLayout.contentTopPadding)
                    .padding(.bottom, SettingLayout.bottomPadding)
            }
            // 내용이 화면보다 짧을 때 이유 없이 튀지 않게 한다.
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dynamicTypeSize(...SettingLayout.maxDynamicTypeSize)
        .background { background }
    }

    // MARK: - 목록

    /// 헤더 없는 카드 한 장에 여섯 행. 순서는 `AppTheme`의 선언 순서이고 시안 순서와 같다.
    private var themeCard: some View {
        CHALLAListSection {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                CHALLAListRow(
                    theme.displayName,
                    icon: .circle,
                    iconColor: theme.themeColor,
                    accessory: .check(isSelected: theme == store.selectedTheme)
                ) {
                    send(.themeTapped(theme))
                }
            }
        }
    }

    // MARK: - 배경

    /// 바닥에 깔리는 테마색 번짐 (시안 `ref_theme.png`에만 있는 장식).
    ///
    /// Figma 수치(390×254 타원 · 블러 300)를 그대로 옮기면 훨씬 옅게 나와, *결과*에 맞춘다 —
    /// 타원을 가로로 늘리고 세로 중심을 화면 바닥선에 두어 맨 아랫줄이 가장 넓은 지름과 겹치게 한다.
    /// (실측 비교는 MODULE.md의 "알려진 차이")
    private var background: some View {
        ZStack(alignment: .bottom) {
            CHALLAColor.Background.surface
            Ellipse()
                .fill(store.selectedTheme.themeColor.opacity(Metric.glowOpacity))
                .frame(height: Metric.glowHeight)
                // 화면보다 넓게 — 좌우 끝까지 세기가 거의 유지되는 시안의 가로 분포를 만든다.
                .scaleEffect(x: Metric.glowWidthScale, anchor: .bottom)
                // 타원의 세로 중심을 화면 바닥선에 맞춘다 (아래 절반은 화면 밖).
                .offset(y: Metric.glowHeight / 2)
                .blur(radius: Metric.glowBlurRadius)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true) // 장식 — 선택 상태는 체크 트레잇이 전달한다
    }
}

// MARK: - Metric

private enum Metric {
    /// 번짐 타원의 세로 지름. 절반이 화면 밖으로 나가므로 화면에 보이는 높이는 이 값의 절반이다
    /// (시안의 번짐이 바닥에서 약 190까지 올라온다).
    static let glowHeight: CGFloat = 380
    /// 가로 지름을 화면 폭의 몇 배로 늘릴지.
    static let glowWidthScale: CGFloat = 1.25
    static let glowOpacity: Double = 0.1
    static let glowBlurRadius: CGFloat = 60
}

#Preview {
    ThemeView(
        store: Store(initialState: ThemeFeature.State(selectedTheme: .lemonade)) {
            ThemeFeature()
        }
    )
}
