import CHALLADesignSystem
import SwiftUI

struct LoginBrandView: View {

    var body: some View {
        VStack(spacing: 21) { // 시안: 워드마크 밑선 → 태그라인 상자 20.6pt
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
        HStack(alignment: .bottom, spacing: 3.5) {
            Image("challaSymbol", bundle: .module)
                .resizable()
                .frame(width: 60, height: 60)
                .padding(.bottom, -5.5)

            Text("challa")
                .challaFont(.heading.xlarge)
                .foregroundStyle(CHALLAColor.Label.strong)
                .padding(.bottom, -14.5)

            Rectangle()
                .fill(CHALLAColor.Primary.yellow)
                .frame(width: 8, height: 8)
                .padding(.leading, 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("challa")
    }
}

#Preview {
    ZStack {
        CHALLAColor.Background.surface.ignoresSafeArea()
        LoginBrandView()
    }
}
