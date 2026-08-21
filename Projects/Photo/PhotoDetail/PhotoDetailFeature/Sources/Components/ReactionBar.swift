import CHALLADesignSystem
import PhotoDomain
import SwiftUI

/// 사진 아래 리액션 버튼 줄. 10종이 5개씩 두 페이지로 나뉘어 좌우 스와이프된다.
/// 내가 이미 남긴 리액션 칩의 경우 테마색 적용
struct ReactionBar: View {

    // MARK: - 프로퍼티

    let selectedKinds: Set<ReactionKind>
    let onTap: (ReactionKind) -> Void

    /// 5개씩 나눈 페이지.
    private var pages: [[ReactionKind]] {
        let all = ReactionKind.allCases
        return stride(from: 0, to: all.count, by: Metric.perPage).map {
            Array(all[$0 ..< min($0 + Metric.perPage, all.count)])
        }
    }

    // MARK: - Body

    var body: some View {
        TabView {
            ForEach(pages.indices, id: \.self) { page in
                row(pages[page])
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: Metric.chipSize)
    }

    private func row(_ kinds: [ReactionKind]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(kinds.enumerated()), id: \.element) { index, kind in
                Button { onTap(kind) } label: { chip(kind) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(kind.accessibilityLabel) 리액션")
                    .accessibilityAddTraits(selectedKinds.contains(kind) ? [.isSelected] : [])

                if index < kinds.count - 1 {
                    Spacer(minLength: 0)
                }
            }
        }
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
                    Circle().strokeBorder(CHALLAColor.defaultTheme, lineWidth: 2)
                }
            }
            .frame(width: Metric.chipSize, height: Metric.chipSize)
    }
}

// MARK: - Figma 실측값

private enum Metric {
    static let perPage = 5
    static let chipSize: CGFloat = 58
    static let emojiSize: CGFloat = 32
}
