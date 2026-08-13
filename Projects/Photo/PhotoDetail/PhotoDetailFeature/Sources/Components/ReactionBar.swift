import CHALLADesignSystem
import PhotoDomain
import SwiftUI

/// 사진 아래 리액션 버튼 줄. 종류 5개가 시안 순서 그대로 놓인다.
struct ReactionBar: View {

    // MARK: - 프로퍼티

    /// 내가 이미 남긴 종류. 시안에 눌린 칩의 모습이 없어 VoiceOver 표시에만 쓴다.
    let selectedKinds: Set<ReactionKind>
    let onTap: (ReactionKind) -> Void

    // MARK: - Body

    var body: some View {
        // 칩(58)은 고정 크기라 HStack이 줄여 주지 않는다. 사이를 Spacer로 균등 분배해
        // 넓은 화면에선 벌어지고 좁은 기기(375pt)에선 자연히 좁아지게 한다 — 390pt(시안 기기)에선 13.
        HStack(spacing: 0) {
            ForEach(Array(ReactionKind.allCases.enumerated()), id: \.element) { index, kind in
                Button { onTap(kind) } label: { chip(kind) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(kind.accessibilityLabel) 리액션")
                    .accessibilityAddTraits(selectedKinds.contains(kind) ? [.isSelected] : [])

                if index < ReactionKind.allCases.count - 1 {
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func chip(_ kind: ReactionKind) -> some View {
        Circle()
            .fill(CHALLAColor.Material.floating)
            .frame(width: Metric.chipSize, height: Metric.chipSize)
            .overlay { Text(kind.emoji).font(.system(size: Metric.emojiSize)) }
    }
}

// MARK: - Figma 실측값

private enum Metric {
    static let chipSize: CGFloat = 58
    static let emojiSize: CGFloat = 32
}
