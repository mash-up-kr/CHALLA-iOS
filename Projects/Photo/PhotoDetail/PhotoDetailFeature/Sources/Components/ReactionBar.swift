import CHALLADesignSystem
import PhotoDomain
import SwiftUI

/// 가로 스크롤을 지원하는 이모지 선택 목록.
/// 내가 이미 남긴 리액션 칩의 경우 테마색 적용
struct ReactionBar: View {

    // MARK: - 프로퍼티

    @Environment(\.challaTheme) private var theme

    let selectedKinds: Set<ReactionKind>
    let onTap: (ReactionKind) -> Void

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Metric.chipSpacing) {
                ForEach(ReactionKind.allCases, id: \.self) { kind in
                    Button { onTap(kind) } label: { chip(kind) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(kind.accessibilityLabel) 리액션")
                        .accessibilityAddTraits(selectedKinds.contains(kind) ? [.isSelected] : [])
                }
            }
            // 스크롤 영역이 좁아지지 않도록 콘텐츠에 여백을 적용한다.
            .padding(.horizontal, Metric.horizontalPadding)
        }
        .scrollIndicators(.hidden)
        .frame(height: Metric.chipSize)
    }

    private func chip(_ kind: ReactionKind) -> some View {
        Circle()
            .fill(CHALLAColor.Material.floating)
            .overlay {
                kind.emoji.barImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: Metric.emojiSize, height: Metric.emojiSize)
            }
            .overlay {
                if selectedKinds.contains(kind) {
                    Circle().strokeBorder(theme.accent, lineWidth: 2)
                }
            }
            .frame(width: Metric.chipSize, height: Metric.chipSize)
    }
}

// MARK: - Figma 실측값

private enum Metric {
    static let chipSize: CGFloat = 58
    /// 시안에서 6번째 칩이 화면 오른쪽에 일부 걸쳐 보이는 간격.
    static let chipSpacing: CGFloat = 10
    static let horizontalPadding: CGFloat = 24
    static let emojiSize: CGFloat = 32
}
