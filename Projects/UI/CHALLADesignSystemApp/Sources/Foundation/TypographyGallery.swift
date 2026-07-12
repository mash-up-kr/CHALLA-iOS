import SwiftUI
import CHALLADesignSystem

/// Foundation > Typography 검수 화면.
/// Figma 구조(그룹 > 크기 > 굵기)를 그대로 나열해 스펙과 1:1로 대조할 수 있게 한다.
struct TypographyGallery: View {
    var body: some View {
        List {
            Section("Heading") {
                row("home", CHALLAFont.Heading.home, sample: "challa")
                row("xlarge · bold", CHALLAFont.Heading.xlarge, sample: "challa")
                sizeRows("large", CHALLAFont.Heading.large)
                sizeRows("medium", CHALLAFont.Heading.medium)
                sizeRows("small", CHALLAFont.Heading.small)
            }

            Section("Body") {
                sizeRows("large", CHALLAFont.Body.large)
                sizeRows("medium", CHALLAFont.Body.medium)
                sizeRows("small", CHALLAFont.Body.small)
            }

            Section("Description") {
                sizeRows("large", CHALLAFont.Description.large)
                sizeRows("medium", CHALLAFont.Description.medium)
                sizeRows("small", CHALLAFont.Description.small)
            }
        }
        .navigationTitle("Typography")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 한 크기 그룹의 3굵기(bold/medium/regular)를 묶어서 나열.
    private func sizeRows(_ size: String, _ set: CHALLAFont.WeightSet) -> some View {
        Group {
            row("\(size) · bold", set.bold)
            row("\(size) · medium", set.medium)
            row("\(size) · regular", set.regular)
        }
    }

    /// 스타일 한 줄: 이름 + 크기/행간 + 샘플 텍스트.
    private func row(
        _ name: String,
        _ typography: CHALLATypography,
        sample: String = "이런 서비스 어때요"
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(name)  ·  \(Int(typography.size))/\(Int(typography.lineHeight))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(sample)
                .challaFont(typography)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        TypographyGallery()
    }
}
