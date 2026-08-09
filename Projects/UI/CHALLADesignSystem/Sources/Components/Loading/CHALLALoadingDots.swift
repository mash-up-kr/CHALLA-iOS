import SwiftUI

/// 로딩 인디케이터 — 점 3개가 순차로 밝아졌다 어두워진다 (opacity 1.0↔0.3, 주기 0.6초, 점당 0.2초 지연).
/// 진행 상태 전달은 담는 쪽의 책임이다 — 이 뷰는 장식으로 취급되어 VoiceOver에 잡히지 않고,
/// 손동작 줄이기(Reduce Motion) 설정 시 애니메이션 없이 정지 상태로 표시된다.
///
/// ```swift
/// CHALLALoadingDots()
/// CHALLALoadingDots(color: CHALLAColor.Primary.yellow, diameter: 8, spacing: 6)
/// ```
public struct CHALLALoadingDots: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    private let color: Color
    private let diameter: CGFloat
    private let spacing: CGFloat

    /// - Parameters:
    ///   - color: 점 색. 기본값은 시안 실측(#A1A1A1)에 가장 가까운 토큰.
    ///   - diameter: 점 지름.
    ///   - spacing: 점 사이 간격.
    public init(
        color: Color = CHALLAColor.Label.neutral,
        diameter: CGFloat = 6,
        spacing: CGFloat = 5
    ) {
        self.color = color
        self.diameter = diameter
        self.spacing = spacing
    }

    public var body: some View {
        HStack(spacing: spacing) {
            ForEach(0 ..< Metric.dotCount, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: diameter, height: diameter)
                    .opacity(isAnimating ? Metric.fadedOpacity : 1)
                    .animation(animation(delayIndex: index), value: isAnimating)
            }
        }
        .accessibilityHidden(true)
        .onAppear { isAnimating = !reduceMotion }
        .onChange(of: reduceMotion) { _, reduce in
            isAnimating = !reduce
        }
    }

    private func animation(delayIndex: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        return .easeInOut(duration: Metric.fadeDuration)
            .repeatForever(autoreverses: true)
            .delay(Double(delayIndex) * Metric.dotDelay)
    }
}

// MARK: - 시안 실측값

private enum Metric {
    static let dotCount = 3
    static let fadedOpacity = 0.3
    /// 편도 페이드 시간. autoreverse 왕복이 한 주기(0.6초)를 이룬다.
    static let fadeDuration = 0.3
    /// 점 사이 시작 시차 — 순차로 밝아지는 효과를 만든다.
    static let dotDelay = 0.2
}

#Preview {
    VStack(spacing: 32) {
        CHALLALoadingDots()
        CHALLALoadingDots(color: CHALLAColor.Primary.yellow, diameter: 8, spacing: 6)
    }
    .padding(40)
    .background(CHALLAColor.Background.surface)
}
