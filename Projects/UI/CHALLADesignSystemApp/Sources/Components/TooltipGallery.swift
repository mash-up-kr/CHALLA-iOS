import CHALLADesignSystem
import SwiftUI

/// Component > Tooltip 검수 화면.
/// position 4방향 × arrowAlignment 3위치 전 조합과 문구 길이 경계, 반투명 배경 비침을 나열한다.
struct TooltipGallery: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                positionSection
                verticalAlignmentSection
                horizontalAlignmentSection
                lengthSection
                onContentSection
            }
            .padding(20)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("Tooltip")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("position")
            galleryCaption("앵커(점선 상자) 기준 툴팁이 놓이는 방향 — 화살표가 앵커를 가리킨다")
            Grid(horizontalSpacing: 24, verticalSpacing: 24) {
                GridRow {
                    VStack(spacing: 0) {
                        CHALLATooltip("top", arrowAlignment: .center)
                        anchorBox
                    }
                    VStack(spacing: 0) {
                        anchorBox
                        CHALLATooltip("bottom", position: .bottom, arrowAlignment: .center)
                    }
                }
                GridRow {
                    HStack(spacing: 0) {
                        CHALLATooltip("leading", position: .leading, arrowAlignment: .center)
                        anchorBox
                    }
                    HStack(spacing: 0) {
                        anchorBox
                        CHALLATooltip("trailing", position: .trailing, arrowAlignment: .center)
                    }
                }
            }
        }
    }

    private var verticalAlignmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("arrowAlignment — 세로 화살표")
            galleryCaption("leading(default) · center · trailing — 모서리 끝 8 안쪽부터")
            alignmentRows(position: .top, label: "position = top")
            alignmentRows(position: .bottom, label: "position = bottom")
        }
    }

    private var horizontalAlignmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("arrowAlignment — 가로 화살표")
            galleryCaption("세로 모서리에서는 leading=위 · center · trailing=아래")
            // 한 줄 높이(34)에선 세 위치 차이가 2pt뿐이라 여러 줄 문구로 벌려 보인다.
            alignmentRows(position: .leading, label: "position = leading", message: Self.multilineSample)
            alignmentRows(position: .trailing, label: "position = trailing", message: Self.multilineSample)
        }
    }

    /// 한 position의 정렬 3위치 전수. 두 정렬 섹션이 합쳐 4방향 × 3위치 12조합을 나열한다.
    private func alignmentRows(
        position: CHALLATooltip.Position,
        label: String,
        message: String = Self.sample
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            galleryCaption(label)
            CHALLATooltip(message, position: position, arrowAlignment: .leading)
            CHALLATooltip(message, position: position, arrowAlignment: .center)
            CHALLATooltip(message, position: position, arrowAlignment: .trailing)
        }
    }

    private var lengthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("문구 길이")
            galleryCaption("짧은 문구 — 최소 폭 64")
            CHALLATooltip("확인")
            galleryCaption("긴 문구 — 내용 폭 256에서 줄바꿈")
            CHALLATooltip("사진이 모두 인화되면 알려드릴게요. 인화가 끝날 때까지 잠시만 기다려 주세요.")
        }
    }

    private var onContentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("배경 위 (blur 확인)")
            galleryCaption("반투명 + ultraThinMaterial이라 뒤 배경이 비친다")
            ZStack {
                RoundedRectangle(cornerRadius: CHALLARadius.xlarge)
                    .fill(CHALLAColor.Primary.yellow)
                    .frame(height: 120)
                CHALLATooltip(Self.sample, arrowAlignment: .center)
            }
        }
    }

    private static let sample = "메시지에 마침표를 찍어요."
    private static let multilineSample = "사진이 모두 인화되면 알려드릴게요. 인화가 끝날 때까지 잠시만 기다려 주세요. 완성된 사진은 보관함에서 다시 볼 수 있어요."

    private var anchorBox: some View {
        RoundedRectangle(cornerRadius: CHALLARadius.small)
            .strokeBorder(
                CHALLAColor.Label.alternative,
                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
            )
            .frame(width: 44, height: 44)
    }

    private func galleryTitle(_ text: String) -> some View {
        Text(text)
            .challaFont(.body.large.bold)
            .foregroundStyle(CHALLAColor.Label.strong)
    }

    private func galleryCaption(_ text: String) -> some View {
        Text(text)
            .challaFont(.body.xsmall.bold)
            .foregroundStyle(CHALLAColor.Label.alternative)
    }
}

#Preview {
    NavigationStack {
        TooltipGallery()
    }
}
