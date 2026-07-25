import SwiftUI
import CHALLADesignSystem

/// Component > TextField 검수 화면.
/// Figma textfield의 상태 5가지 + customize(정렬·타이포·테두리 색)를 나열한다.
/// focus·typing 상태는 정적 나열이 불가능하므로 직접 탭해서 확인한다 (커서·테두리 = 노랑).
struct TextFieldGallery: View {

    // 섹션마다 독립된 상태를 쓴다 — 공유하면 한쪽 입력이 다른 섹션에 나타나 검수를 오인시킨다
    @State private var interactive = ""
    @State private var typed = "텍스트"
    @State private var centerAligned = ""
    @State private var leadingText = ""
    @State private var customBorder = ""
    @State private var customTypo = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                stateSection
                alignmentSection
                customizeSection
            }
            .padding(20)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("TextField")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 상태 검수: placeholder → (탭하면 focus·typing) → typed → disabled 순.
    private var stateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("State")
            galleryCaption("Placeholder → 탭해서 Focus·Typing 확인")
            CHALLATextField(text: $interactive, placeholder: "내용을 입력해 주세요.")
            galleryCaption("Typed")
            CHALLATextField(text: $typed, placeholder: "내용을 입력해 주세요.")
            galleryCaption("Disabled")
            CHALLATextField(text: $typed, placeholder: "내용을 입력해 주세요.")
                .disabled(true)
        }
    }

    /// 정렬 검수: 기본 중앙 vs 왼쪽 (방 만들기 실사용 오버라이드).
    private var alignmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Alignment")
            galleryCaption("Center (기본)")
            CHALLATextField(text: $centerAligned, placeholder: "내용을 입력해 주세요.")
            galleryCaption("Leading (방 만들기 실사용)")
            CHALLATextField(text: $leadingText, placeholder: "방 이름 입력", textAlignment: .leading)
        }
    }

    /// customize 검수: Figma customize 속성인 타이포·테두리 색 주입.
    private var customizeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Customize")
            galleryCaption("borderColor = Primary.sky (탭해서 테두리·커서 색 확인)")
            CHALLATextField(
                text: $customBorder,
                placeholder: "내용을 입력해 주세요.",
                borderColor: CHALLAColor.Primary.sky
            )
            galleryCaption("typography = body.large.bold")
            CHALLATextField(
                text: $customTypo,
                placeholder: "내용을 입력해 주세요.",
                typography: .body.large.bold
            )
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
        TextFieldGallery()
    }
}
