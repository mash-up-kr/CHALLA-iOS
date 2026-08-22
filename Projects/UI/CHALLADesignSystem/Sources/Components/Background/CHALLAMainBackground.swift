import SwiftUI

// MARK: - challaMainBackground

public extension View {
    /// 찰나 앱의 기본 화면 배경 — surface 색 위에 하단에서 테마 색이 번진다.
    ///
    /// 시안의 배경은 그라데이션이 아니라 블러를 먹인 타원 하나다. 타원 중심이 화면 아래에
    /// 있어 하단만 은은하게 밝아진다. 홈·방 상세 등 화면 단위 뷰의 최상단에 붙인다.
    func challaMainBackground() -> some View {
        modifier(MainBackgroundModifier())
    }
}

// MARK: - 구현

/// Environment를 읽어야 해서 View 확장이 아니라 modifier로 둔다.
private struct MainBackgroundModifier: ViewModifier {

    @Environment(\.challaTheme) private var theme

    func body(content: Content) -> some View {
        content.background {
            ZStack(alignment: .bottom) {
                CHALLAColor.Background.surface
                Ellipse()
                    .fill(theme.glow.opacity(MainBackgroundMetric.tintOpacity))
                    .frame(
                        width: MainBackgroundMetric.ellipseWidth,
                        height: MainBackgroundMetric.ellipseHeight
                    )
                    .blur(radius: MainBackgroundMetric.blurRadius)
                    // 타원 중심을 화면 바닥 아래로 내려 하단 가장자리만 물들게 한다.
                    .offset(y: MainBackgroundMetric.ellipseHeight / 2
                        + MainBackgroundMetric.centerDropBelowBottom)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Figma 실측값

private enum MainBackgroundMetric {
    /// 타원 크기 (777×594 — 화면 폭 390보다 넓어 좌우 가장자리까지 번진다).
    static let ellipseWidth: CGFloat = 777
    static let ellipseHeight: CGFloat = 594
    /// 타원 중심이 화면 바닥에서 아래로 내려간 거리.
    static let centerDropBelowBottom: CGFloat = 43
    /// 칠 투명도 (#EAFF00 20%).
    static let tintOpacity: CGFloat = 0.2
    /// Figma 레이어 블러 300의 절반 — 시안 육안 근사값, 디자이너 검수로 확정한다.
    static let blurRadius: CGFloat = 150
}

#Preview {
    VStack {
        Text("찰나 메인 배경")
            .challaFont(.body.large.bold)
            .foregroundStyle(CHALLAColor.Label.strong)
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .challaMainBackground()
}
