import CHALLADesignSystem
import SwiftUI

/// Component > Button 검수 화면.
/// variant × size × 활성/비활성 조합을 전수 나열한다 (Figma textButton·iconButton 18조합씩).
struct ButtonGallery: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                textButtonSection
                textButtonIconSection
                iconButtonSection
            }
            .padding(20)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("Button")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 텍스트 버튼 18조합. 각 줄: 활성 · 비활성 나란히.
    /// allCases 기반이라 variant·size가 늘어나면 자동으로 나열된다.
    private var textButtonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Text Button")
            ForEach(CHALLAButtonVariant.allCases, id: \.self) { variant in
                VStack(alignment: .leading, spacing: 12) {
                    galleryCaption(String(describing: variant).capitalized)
                    ForEach(CHALLAButtonSize.allCases, id: \.self) { size in
                        HStack(spacing: 12) {
                            CHALLATextButton("버튼명", variant: variant, size: size) {}
                            CHALLATextButton("버튼명", variant: variant, size: size) {}
                                .disabled(true)
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    /// 텍스트 버튼 아이콘 배치 3조합 (Neutral·Large 기준): 왼쪽만 / 오른쪽만 / 양쪽.
    private var textButtonIconSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Text Button + Icon")
            HStack(spacing: 12) {
                CHALLATextButton("버튼명", variant: .neutral, leadingIcon: .check) {}
                CHALLATextButton("버튼명", variant: .neutral, trailingIcon: .caretRight) {}
                Spacer()
            }
            HStack(spacing: 12) {
                CHALLATextButton("버튼명", variant: .neutral, leadingIcon: .check, trailingIcon: .caretRight) {}
                Spacer()
            }
        }
    }

    /// 아이콘 버튼 18조합. 각 줄: 활성 · 비활성 나란히.
    /// allCases 기반이라 variant·size가 늘어나면 자동으로 나열된다.
    private var iconButtonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Icon Button")
            ForEach(CHALLAButtonVariant.allCases, id: \.self) { variant in
                VStack(alignment: .leading, spacing: 12) {
                    galleryCaption(String(describing: variant).capitalized)
                    ForEach(CHALLAButtonSize.allCases, id: \.self) { size in
                        HStack(spacing: 12) {
                            CHALLAIconButton(.camera, accessibilityLabel: "촬영", variant: variant, size: size) {}
                            CHALLAIconButton(.camera, accessibilityLabel: "촬영", variant: variant, size: size) {}
                                .disabled(true)
                            Spacer()
                        }
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

    private func galleryCaption(_ text: String) -> some View {
        Text(text)
            .challaFont(.body.xsmall.bold)
            .foregroundStyle(CHALLAColor.Label.alternative)
    }
}

#Preview {
    NavigationStack {
        ButtonGallery()
    }
}
