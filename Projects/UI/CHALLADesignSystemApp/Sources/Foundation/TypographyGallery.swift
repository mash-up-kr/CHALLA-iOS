import SwiftUI
import CHALLADesignSystem

/// Foundation > Typography 검수 화면.
/// Figma 구조(그룹 > 크기 > 굵기)를 그대로 나열해 스펙과 1:1로 대조할 수 있게 한다.
/// 토큰은 실제 호출부와 같은 문법(.heading.large.bold)으로 넘겨 사용 예시를 겸한다.
struct TypographyGallery: View {
    var body: some View {
        List {
            Section("Heading") {
                row("home", .heading.home, sample: "challa")
                row("xlarge · bold", .heading.xlarge, sample: "challa")
                row("large · bold", .heading.large.bold)
                row("large · medium", .heading.large.medium)
                row("large · regular", .heading.large.regular)
                row("medium · bold", .heading.medium.bold)
                row("medium · medium", .heading.medium.medium)
                row("medium · regular", .heading.medium.regular)
                row("small · bold", .heading.small.bold)
                row("small · medium", .heading.small.medium)
                row("small · regular", .heading.small.regular)
            }

            Section("Body") {
                row("large · bold", .body.large.bold)
                row("large · medium", .body.large.medium)
                row("large · regular", .body.large.regular)
                row("medium · bold", .body.medium.bold)
                row("medium · medium", .body.medium.medium)
                row("medium · regular", .body.medium.regular)
                row("small · bold", .body.small.bold)
                row("small · medium", .body.small.medium)
                row("small · regular", .body.small.regular)
            }

            Section("Description") {
                row("large · bold", .description.large.bold)
                row("large · medium", .description.large.medium)
                row("large · regular", .description.large.regular)
                row("medium · bold", .description.medium.bold)
                row("medium · medium", .description.medium.medium)
                row("medium · regular", .description.medium.regular)
                row("small · bold", .description.small.bold)
                row("small · medium", .description.small.medium)
                row("small · regular", .description.small.regular)
            }
        }
        .navigationTitle("Typography")
        .navigationBarTitleDisplayMode(.inline)
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
