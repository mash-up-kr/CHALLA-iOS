import SwiftUI

/// 디자인 시스템 촬영 매수 선택 줄.
/// 숫자들을 "N장" 칩으로 나열하고 하나만 선택된다. 방 만들기 드로어의 24/48/72장 선택에 쓰인다.
///
/// 선택 상태가 유지되는 라디오 성격이라 텍스트 버튼(`CHALLATextButton`)과 별개 컴포넌트다 —
/// Figma에서도 기존 Button이 아닌 자체 컴포넌트로 정의돼 있다.
///
/// 선택값을 `Binding`이 아니라 값 + 콜백으로 받는다. 이 컴포넌트는 선택을 스스로 바꾸지 않고
/// 탭 사실만 알린다 — 값을 바꾸는 주체를 호출부 하나로 유지하기 위해서다.
/// (상태 변경이 리듀서 안에서만 일어나야 하는 TCA 화면에서 특히 중요하다.)
///
/// ```swift
/// CHALLAPhotoCountSelector(counts: [24, 48, 72], selected: count) { count = $0 }
/// ```
public struct CHALLAPhotoCountSelector: View {

    // MARK: - 프로퍼티와 init

    private let counts: [Int]
    private let selected: Int
    private let onSelect: (Int) -> Void

    /// - Parameters:
    ///   - counts: 나열할 매수들. 표기("N장")는 컴포넌트가 붙인다.
    ///   - selected: 지금 선택된 매수. `counts`에 없는 값이면 아무것도 선택되지 않은 채 그려진다.
    ///   - onSelect: 칩을 탭하면 그 매수를 넘겨준다. 선택 상태 변경은 호출부 몫이다.
    public init(
        counts: [Int],
        selected: Int,
        onSelect: @escaping (Int) -> Void
    ) {
        self.counts = counts
        self.selected = selected
        self.onSelect = onSelect
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: PhotoCountMetric.spacing) {
            ForEach(counts, id: \.self) { count in
                option(count)
            }
        }
    }

    // MARK: - 칩

    private func option(_ count: Int) -> some View {
        let isSelected = count == selected
        return Button {
            onSelect(count)
        } label: {
            Text("\(count)장")
                .challaFont(.body.medium.bold)
                .foregroundStyle(
                    isSelected ? CHALLAColor.Label.normal : CHALLAColor.Label.neutral
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, PhotoCountMetric.verticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: PhotoCountMetric.cornerRadius)
                        .fill(
                            isSelected
                                ? CHALLAColor.Background.level4
                                : CHALLAColor.Background.level2
                        )
                )
                // 테두리를 채움과 분리해 두는 것은 미선택에서 .clear로 꺼도 칩 크기가 안 변하게 하려는 것.
                .overlay(
                    RoundedRectangle(cornerRadius: PhotoCountMetric.cornerRadius)
                        .strokeBorder(
                            isSelected ? CHALLAColor.Line.normal : .clear,
                            lineWidth: PhotoCountMetric.borderWidth
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Figma 실측값

private enum PhotoCountMetric {
    /// 칩 사이 간격.
    static let spacing: CGFloat = 4
    /// 시안 세로 패딩 16 — challaFont가 줄 높이만큼 더하는 여백을 빼야 시안대로 보인다.
    static let verticalPadding: CGFloat = 16 - CHALLATypography.body.medium.bold.lineBoxInset
    static let cornerRadius: CGFloat = CHALLARadius.large
    static let borderWidth: CGFloat = 1.5
}

#Preview {
    VStack(spacing: 20) {
        CHALLAPhotoCountSelector(counts: [24, 48, 72], selected: 24, onSelect: { _ in })
        CHALLAPhotoCountSelector(counts: [24, 48, 72], selected: 72, onSelect: { _ in })
    }
    .padding()
    .background(CHALLAColor.Background.level1)
}
