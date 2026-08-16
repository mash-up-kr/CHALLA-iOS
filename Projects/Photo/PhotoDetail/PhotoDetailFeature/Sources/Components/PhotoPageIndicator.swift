import CHALLADesignSystem
import SwiftUI

/// 사진 장수를 알리는 점 표시. 현재 장에서 멀어질수록 점이 작아진다.
///
/// 사진이 많아도 점은 최대 `Metric.maxVisible`개만 그린다 —
/// 장수만큼 늘리면 방에 사진이 쌓였을 때 화면 폭을 넘긴다.
struct PhotoPageIndicator: View {

    // MARK: - 프로퍼티

    let count: Int
    let currentIndex: Int

    // MARK: - Body

    var body: some View {
        HStack(spacing: Metric.spacing) {
            ForEach(visibleIndices, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? CHALLAColor.defaultTheme : CHALLAColor.Label.disabled)
                    .frame(width: diameter(at: index), height: diameter(at: index))
            }
        }
        .frame(height: Metric.large)
        .accessibilityElement()
        .accessibilityLabel("사진 \(count)장 중 \(currentIndex + 1)번째")
    }

    // MARK: - 표기 규칙

    /// 현재 장을 가운데 두는 창. 양 끝에서는 창이 밀려 가장자리에 붙는다.
    var visibleIndices: Range<Int> {
        guard count > Metric.maxVisible else { return 0 ..< max(count, 0) }
        let half = Metric.maxVisible / 2
        let start = min(max(currentIndex - half, 0), count - Metric.maxVisible)
        return start ..< (start + Metric.maxVisible)
    }

    /// 시안 실측 — 현재 점에서 두 칸까지는 10, 세 칸은 8, 그 밖은 6.
    private func diameter(at index: Int) -> CGFloat {
        switch abs(index - currentIndex) {
        case 0 ... 2: Metric.large
        case 3: Metric.medium
        default: Metric.small
        }
    }
}

// MARK: - Figma 실측값

private enum Metric {
    static let large: CGFloat = 10
    static let medium: CGFloat = 8
    static let small: CGFloat = 6
    static let spacing: CGFloat = 8
    /// 시안이 점 5개를 그린다 (10 · 10 · 10 · 8 · 6).
    static let maxVisible = 5
}
