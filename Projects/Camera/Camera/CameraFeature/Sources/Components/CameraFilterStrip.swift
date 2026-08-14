import CHALLADesignSystem
import ComposableArchitecture
import SwiftUI

/// 가로로 넘겨 고르는 필터 띠.
/// 선택 항목이 항상 화면 중앙에 물리고, 탭과 스크롤 어느 쪽으로도 선택이 바뀐다.
struct CameraFilterStrip: View {

    /// `CameraView`가 상단 뭉치 전체 높이를 계산할 때 참조하는 이 컴포넌트의 외부 치수.
    static let height: CGFloat = 44

    let filters: IdentifiedArrayOf<CameraFilter>
    let selectedFilterID: CameraFilter.ID?
    let onSelect: (CameraFilter.ID) -> Void

    /// ScrollView가 요구하는 표시용 상태. 진짜 선택값은 store의 selectedFilterID다.
    @State private var scrolledID: CameraFilter.ID?

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(filters) { filter in
                        Button {
                            onSelect(filter.id)
                        } label: {
                            cell(filter)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrolledID, anchor: .center)
            .contentMargins(.horizontal, centeringMargin(in: proxy.size.width), for: .scrollContent)
            .mask(edgeFade)
        }
        .frame(height: Self.height)
        .padding(.vertical, FilterStripMetric.verticalPadding)
        .onAppear { scrolledID = selectedFilterID }
        .onChange(of: selectedFilterID) { _, selected in
            guard selected != scrolledID else { return }
            withAnimation { scrolledID = selected }
        }
        .onChange(of: scrolledID) { _, scrolled in
            guard let scrolled, scrolled != selectedFilterID else { return }
            onSelect(scrolled)
        }
    }

    private func cell(_ filter: CameraFilter) -> some View {
        Text(filter.name)
            .challaFont(.body.medium.bold)
            .foregroundStyle(
                filter.id == selectedFilterID
                    ? CHALLAColor.Label.normal
                    : CHALLAColor.Label.alternative
            )
            .lineLimit(1)
            .frame(width: FilterStripMetric.itemWidth, height: Self.height)
            .contentShape(Rectangle())
    }

    /// 첫·마지막 항목도 중앙까지 올 수 있도록 양쪽에 남기는 여백.
    private func centeringMargin(in width: CGFloat) -> CGFloat {
        max(0, (width - FilterStripMetric.itemWidth) / 2)
    }

    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: CHALLAColor.Static.black.opacity(0), location: 0),
                .init(color: CHALLAColor.Static.black, location: 0.12),
                .init(color: CHALLAColor.Static.black, location: 0.88),
                .init(color: CHALLAColor.Static.black.opacity(0), location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Figma 실측값

private enum FilterStripMetric {
    static let verticalPadding: CGFloat = 10
    /// 시안 항목 간격(텍스트 38 + gap 20). 선택 항목을 화면 중앙에 물리려면 항목 폭이 일정해야 한다.
    static let itemWidth: CGFloat = 58
}

#Preview {
    struct PreviewHost: View {
        @State private var selected: CameraFilter.ID? = "3"

        var body: some View {
            CameraFilterStrip(
                filters: IdentifiedArray(uniqueElements: (1 ... 8).map {
                    CameraFilter(id: "\($0)", name: "필터\($0)")
                }),
                selectedFilterID: selected,
                onSelect: { selected = $0 }
            )
            .frame(maxHeight: .infinity)
            .background(CHALLAColor.Static.black)
        }
    }
    return PreviewHost()
}
