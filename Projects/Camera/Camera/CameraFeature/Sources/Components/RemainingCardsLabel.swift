import CHALLADesignSystem
import SwiftUI

/// "3장 남음 /48장" — 남은 장수는 단계별 색, 총 장수는 항상 보조 색.
struct RemainingCardsLabel: View {

    /// `CameraView`가 하단 뭉치 전체 높이를 계산할 때 쓰는 이 컴포넌트의 한 줄 높이 육안 근사값
    /// — 디자이너 검수로 확정한다.
    static let heightEstimate: CGFloat = 18

    let remaining: Int
    let total: Int

    var body: some View {
        HStack(spacing: RemainingCardsLabelMetric.spacing) {
            Text("\(remaining)장 남음")
                .foregroundStyle(CameraCardsLevel(remaining: remaining).color)
            Text("/\(total)장")
                .foregroundStyle(CHALLAColor.Label.alternative)
        }
        .challaFont(.body.xsmall.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("총 \(total)장 중 \(remaining)장 남음")
    }
}

extension CameraCardsLevel {

    var color: Color {
        switch self {
        case .normal: CHALLAColor.Label.normal
        case .low: CHALLAColor.Status.destructive
        case .unavailable: CHALLAColor.Label.disabled
        }
    }
}

// MARK: - Figma 실측값

private enum RemainingCardsLabelMetric {
    static let spacing: CGFloat = 4
}

#Preview {
    VStack(spacing: 12) {
        RemainingCardsLabel(remaining: 6, total: 24)
        RemainingCardsLabel(remaining: 5, total: 48)
        RemainingCardsLabel(remaining: 0, total: 48)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CHALLAColor.Static.black)
}
