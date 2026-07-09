import SwiftUI
import CHALLADesignSystem

/// Foundation > Color 검수 화면.
/// CHALLAColor의 각 그룹을 스와치 + 이름으로 나열한다. (YDS Stage 참고)
struct ColorGallery: View {
    var body: some View {
        List {
            colorSection("Primary", colors: [
                ("Pink", CHALLAColor.Primary.pink),
                ("Orange", CHALLAColor.Primary.orange),
                ("Yellow", CHALLAColor.Primary.yellow),
                ("Sky", CHALLAColor.Primary.sky),
                ("Blue", CHALLAColor.Primary.blue),
                ("Purple", CHALLAColor.Primary.purple)
            ])

            colorSection("Label", colors: [
                ("Strong", CHALLAColor.Label.strong),
                ("Normal", CHALLAColor.Label.normal),
                ("Subtle", CHALLAColor.Label.subtle),
                ("Neutral", CHALLAColor.Label.neutral),
                ("Alternative", CHALLAColor.Label.alternative),
                ("Disabled", CHALLAColor.Label.disabled)
            ])

            colorSection("Background", colors: [
                ("Surface", CHALLAColor.Background.surface),
                ("Level 1", CHALLAColor.Background.level1),
                ("Level 2", CHALLAColor.Background.level2),
                ("Level 3", CHALLAColor.Background.level3),
                ("Level 4", CHALLAColor.Background.level4)
            ])

            colorSection("Line", colors: [
                ("Normal", CHALLAColor.Line.normal),
                ("Neutral", CHALLAColor.Line.neutral),
                ("Alternative", CHALLAColor.Line.alternative)
            ])

            colorSection("Static", colors: [
                ("White", CHALLAColor.Static.white),
                ("Black", CHALLAColor.Static.black)
            ])

            colorSection("Material", colors: [
                ("Dimmer", CHALLAColor.Material.dimmer)
            ])
        }
        .navigationTitle("Color")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colorSection(_ title: String, colors: [(String, Color)]) -> some View {
        Section(title) {
            ForEach(colors, id: \.0) { name, color in
                ColorRow(name: name, color: color)
            }
        }
    }
}

/// 색상 한 줄: 스와치 + 이름.
private struct ColorRow: View {
    let name: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    // 흰색/투명 스와치도 경계가 보이도록 테두리
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.gray.opacity(0.3), lineWidth: 1)
                )
            Text(name)
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        ColorGallery()
    }
}
