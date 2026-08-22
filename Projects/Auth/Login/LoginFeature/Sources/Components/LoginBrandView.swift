import CHALLADesignSystem
import SwiftUI

struct LoginBrandView: View {

    var body: some View {
        VStack(spacing: Metric.taglineSpacing) {
            symbolRow

            Text("함께 찍고, 함께 기다리는 우리만의 찰나")
                .challaFont(.heading.xsmall.medium)
                .foregroundStyle(CHALLAColor.Label.strong)
                .multilineTextAlignment(.center)
        }
    }

    /// 시안은 심볼·워드마크·점의 밑선을 맞춘 구성이다. 그런데 Dirtyline 글리프는 텍스트 상자 안에서
    /// 위쪽에 치우쳐 그려지고 심볼 SVG도 아래에 여백이 있어, 상자째 정렬하면 서로 어긋난다.
    /// 그래서 상자 밑에 남는 빈 공간을 음수 패딩으로 덜어내고 정렬한다.
    private var symbolRow: some View {
        HStack(alignment: .bottom, spacing: Metric.symbolRowSpacing) {
            Image("challaSymbol", bundle: .module)
                .resizable()
                .frame(width: Metric.symbolSize, height: Metric.symbolSize)
                .padding(.bottom, Metric.symbolBottomInset)

            Text("challa")
                .challaFont(.heading.xlarge)
                .foregroundStyle(CHALLAColor.Label.strong)
                .padding(.bottom, Metric.wordmarkBottomInset)

            Rectangle()
                .fill(CHALLAColor.Primary.yellow)
                .frame(width: Metric.dotSize, height: Metric.dotSize)
                .padding(.leading, Metric.dotLeadingSpacing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("challa")
    }
}

// MARK: - Figma 실측값

private enum Metric {
    /// 워드마크 밑선에서 태그라인 상자까지 20.6pt.
    static let taglineSpacing: CGFloat = 21

    static let symbolRowSpacing: CGFloat = 3.5
    static let symbolSize: CGFloat = 60
    static let dotSize: CGFloat = 8
    static let dotLeadingSpacing: CGFloat = 2

    /// 상자 밑에 남는 빈 공간만큼 덜어내는 보정값 (`symbolRow` 주석 참고).
    static let symbolBottomInset: CGFloat = -5.5
    static let wordmarkBottomInset: CGFloat = -14.5
}

#Preview {
    ZStack {
        CHALLAColor.Background.surface.ignoresSafeArea()
        LoginBrandView()
    }
}
