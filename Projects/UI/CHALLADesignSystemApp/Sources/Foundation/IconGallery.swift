import SwiftUI
import CHALLADesignSystem

/// Foundation > Icon 검수 화면.
/// 아이콘·버튼이 어두운 배경 기준으로 디자인돼 있어 Background.surface 위에 그린다.
struct IconGallery: View {
    private let columns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                sizeSection
                inventorySection
            }
            .padding(20)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("Icon")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 크기 토큰 검수: 같은 아이콘을 16~32 전 크기로 나열한다.
    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Size")
            HStack(alignment: .bottom, spacing: 16) {
                ForEach(CHALLAIcon.Size.allCases, id: \.rawValue) { size in
                    VStack(spacing: 8) {
                        CHALLAIcon.check.image(size: size)
                        Text("\(Int(size.rawValue))")
                            .challaFont(.body.xsmall.bold)
                            .foregroundStyle(CHALLAColor.Label.alternative)
                    }
                }
            }
        }
    }

    /// 20종 전수 그리드. 이름은 Figma 인벤토리와 대조하기 쉽게 에셋 이름 그대로 표기한다.
    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Inventory (\(CHALLAIcon.allCases.count)종)")
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(CHALLAIcon.allCases, id: \.rawValue) { icon in
                    VStack(spacing: 8) {
                        icon.image()
                        Text(icon.rawValue)
                            .challaFont(.body.xsmall.bold)
                            .foregroundStyle(CHALLAColor.Label.alternative)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
            }
        }
    }

    private func galleryTitle(_ text: String) -> some View {
        Text(text)
            .challaFont(.body.large.bold)
            .foregroundStyle(CHALLAColor.Label.strong)
    }
}

#Preview {
    NavigationStack {
        IconGallery()
    }
}
