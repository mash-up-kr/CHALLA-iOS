import CHALLADesignSystem
import SwiftUI

/// 사진 장수를 나타내는 점 표시. 현재 사진에서 멀어질수록 점이 작아진다.
struct PhotoPageIndicator: View {

    // MARK: - 프로퍼티

    let count: Int
    let currentIndex: Int

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PhotoPageWindow.indices(count: count, current: currentIndex), id: \.self) { index in
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

    /// 시안 실측 — 현재 점에서 두 칸까지는 지름 10, 세 칸은 8, 그 밖은 6.
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
}
