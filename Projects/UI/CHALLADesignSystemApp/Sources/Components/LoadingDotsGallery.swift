import CHALLADesignSystem
import SwiftUI

/// Component > Loading Dots 검수 화면.
/// 애니메이션(순차 페이드 0.6초 주기)은 정적 나열이 불가능하므로 실행 화면에서 직접 확인한다.
/// 손동작 줄이기(Reduce Motion) 설정 시 정지되는지도 설정 토글로 함께 검수한다.
struct LoadingDotsGallery: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                defaultSection
                customizeSection
                inButtonSection
            }
            .padding(20)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("Loading Dots")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 기본값 검수: color = Label.neutral, diameter 6, spacing 5.
    private var defaultSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Default")
            galleryCaption("Label.neutral · 6pt · 간격 5pt")
            CHALLALoadingDots()
        }
    }

    /// customize 검수: 색·지름·간격 주입.
    private var customizeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Customize")
            galleryCaption("color = Primary.yellow")
            CHALLALoadingDots(color: CHALLAColor.Primary.yellow)
            galleryCaption("diameter = 10, spacing = 8")
            CHALLALoadingDots(diameter: 10, spacing: 8)
        }
    }

    /// 실사용 맥락 검수: CHALLATextButton(isLoading:) 안에서의 표시 (프로필 설정 CTA).
    private var inButtonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("In Button (실사용)")
            galleryCaption("CHALLATextButton(isFullWidth: true, isLoading: true)")
            CHALLATextButton("버튼명", isFullWidth: true, isLoading: true) {}
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
        LoadingDotsGallery()
    }
}
