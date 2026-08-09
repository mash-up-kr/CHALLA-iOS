import CHALLADesignSystem
import SwiftUI

/// 환영 화면 하단의 lime 글로우 (장식 전용).
struct WelcomeGlowView: View {

    var body: some View {
        Ellipse()
            .fill(CHALLAColor.Primary.yellow.opacity(Metric.opacity))
            .frame(height: Metric.height)
            .blur(radius: Metric.blurRadius)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Zeplin 실측값

/// 시안(b5fc)의 `Ellipse 9`는 390×254에 `rgba(214,247,0,0.1)` + 가우시안 블러 300이다.
/// 크기·색은 그대로 쓰지만 블러와 알파는 그대로 옮길 수 없다 — SwiftUI `.blur`가 Figma보다
/// 훨씬 넓게 퍼져서 300을 주면 글로우가 배경에 묻혀 사라진다.
/// 그래서 시안 렌더의 밝기 분포(좌우 균일 · 하단 G 33~38)에 맞춰 보정한 값을 쓴다.
private enum Metric {
    static let height: CGFloat = 254
    static let opacity: Double = 0.22
    static let blurRadius: CGFloat = 150
}

#Preview {
    WelcomeGlowView()
        .background(CHALLAColor.Background.surface)
}
