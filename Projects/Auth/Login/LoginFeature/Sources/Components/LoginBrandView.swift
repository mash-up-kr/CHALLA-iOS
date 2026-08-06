import CHALLADesignSystem
import SwiftUI

/// 화면 중앙의 브랜드 그룹 — "challa" 워드마크 + 플레이스홀더 이미지.
struct LoginBrandView: View {

    var body: some View {
        VStack(spacing: 20) {
            Text("challa")
                .foregroundStyle(CHALLAColor.Label.strong)
                .multilineTextAlignment(.center)

            // TODO: Figma Rectangle336 — 임시 플레이스홀더. 실제 브랜드 이미지 확정 시 교체 예정.
            RoundedRectangle(cornerRadius: 12)
                .fill(CHALLAColor.Background.level4)
                .frame(width: 300, height: 300)
        }
        .opacity(0.1)
        .accessibilityHidden(true) // 순수 장식 — 읽어도 조작할 것이 없다
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        CHALLAColor.Background.surface.ignoresSafeArea()
        LoginBrandView()
    }
}
