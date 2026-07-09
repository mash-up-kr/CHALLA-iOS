import SwiftUI
import CHALLADesignSystem

/// Foundation > Typography 검수 화면.
struct TypographyGallery: View {
    var body: some View {
        List {
            Section("Weight") {
                row("bold", CHALLAFont.Weight.bold)
                row("medium", CHALLAFont.Weight.medium)
                row("regular", CHALLAFont.Weight.regular)
            }

            Section("Heading") {
                row("xlarge", CHALLAFont.Heading.xlarge, sample: "challa")
                row("large", CHALLAFont.Heading.large)
                row("medium", CHALLAFont.Heading.medium)
                row("small", CHALLAFont.Heading.small)
            }

            Section("Body") {
                row("large", CHALLAFont.Body.large)
                row("medium", CHALLAFont.Body.medium)
                row("small", CHALLAFont.Body.small)
            }

            Section("Description") {
                row("large", CHALLAFont.Description.large)
                row("medium", CHALLAFont.Description.medium)
                row("small", CHALLAFont.Description.small)
            }
        }
        .navigationTitle("Typography")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 스타일 한 줄: 이름 + 샘플 텍스트.
    private func row(
        _ name: String,
        _ typography: CHALLATypography,
        sample: String = "이런 서비스 어때요"
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
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
