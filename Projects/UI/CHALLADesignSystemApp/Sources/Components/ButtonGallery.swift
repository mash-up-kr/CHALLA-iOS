import SwiftUI
import CHALLADesignSystem

/// Component > Button 검수 화면.
/// variant × size × 활성/비활성 조합을 전수 나열한다 (Figma textButton·iconButton 18조합씩).
struct ButtonGallery: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                textButtonSection
                destructiveSection
                fullWidthSection
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

    /// Destructive role 조합. role은 variant와 별개 파라미터라 allCases 자동 나열이 없어 수동 나열한다.
    /// 비활성 시 빨간 팔레트가 아니라 공통 비활성 팔레트로 떨어지는 것까지 검수 대상이다.
    private var destructiveSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Text Button · Destructive")
            VStack(alignment: .leading, spacing: 12) {
                galleryCaption("Primary — 빨간 채움 (예: 그래도 탈퇴하기)")
                HStack(spacing: 12) {
                    CHALLATextButton("버튼명", role: .destructive) {}
                    CHALLATextButton("버튼명", role: .destructive) {}
                        .disabled(true)
                    Spacer()
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                galleryCaption("Neutral — 빨간 글자 (예: 프로필 사진 삭제)")
                HStack(spacing: 12) {
                    CHALLATextButton("버튼명", variant: .neutral, role: .destructive) {}
                    CHALLATextButton("버튼명", variant: .neutral, role: .destructive) {}
                        .disabled(true)
                    Spacer()
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                galleryCaption("Transparent — 빨간 글자 (Figma 예시 없음 · 확장 정의)")
                HStack(spacing: 12) {
                    CHALLATextButton("버튼명", variant: .transparent, role: .destructive) {}
                    CHALLATextButton("버튼명", variant: .transparent, role: .destructive) {}
                        .disabled(true)
                    Spacer()
                }
            }
        }
    }

    /// 전체 폭(isFullWidth) 조합. 드로어 버튼 스택이 쓰는 형태 —
    /// 배경·터치 영역이 부모 폭까지 늘어나는지, 글자가 가운데 오는지 검수한다.
    private var fullWidthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Text Button · Full Width")
            galleryCaption("기본(내용 폭)과 대조")
            CHALLATextButton("버튼명") {}
            CHALLATextButton("버튼명", isFullWidth: true) {}
            CHALLATextButton("버튼명", variant: .neutral, isFullWidth: true) {}
            CHALLATextButton("보조 액션", variant: .transparent, size: .medium, isFullWidth: true) {}
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
