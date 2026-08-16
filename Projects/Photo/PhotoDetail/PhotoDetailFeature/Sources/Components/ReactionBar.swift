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
        HStack(spacing: Metric.spacing) {
            ForEach(ReactionKind.allCases, id: \.self) { kind in
                Button { onTap(kind) } label: { chip(kind) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(kind.accessibilityLabel) 리액션")
                    .accessibilityAddTraits(selectedKinds.contains(kind) ? [.isSelected] : [])
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
    /// 폭 342에 58짜리 5개를 넣고 남은 간격.
    static let spacing: CGFloat = 13
}
