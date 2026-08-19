import CHALLADesignSystem
import SwiftUI

/// Component > SnackBar 검수 화면.
/// 스낵바는 화면 하단에 좌우로 꽉 차게 놓이므로, 실제 폭(좌우 12)과 같은 여백으로 나열한다.
struct SnackBarGallery: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                variantSection
                onContentSection
            }
            .padding(.vertical, 20)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("SnackBar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var variantSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Variant")
            galleryCaption("문구 + 액션 — camera_snackBar_1")
            CHALLASnackBar("셔터를 누르는 순간 장수가 차감돼요.", action: .init("다음") {})
            galleryCaption("문구 + 액션 — camera_snackBar_2")
            CHALLASnackBar("신중하게 셔터를 눌러 보세요.", action: .init("확인") {})
            galleryCaption("액션 없음")
            CHALLASnackBar("액션 없이 문구만 있는 스낵바예요.")
            galleryCaption("긴 문구 — 줄바꿈 + 액션 폭 유지 확인")
            CHALLASnackBar(
                "한 줄에 담기지 않는 아주 긴 안내 문구가 들어왔을 때 어떻게 접히는지 확인한다.",
                action: .init("확인") {}
            )
            galleryCaption("긴 액션 문구")
            CHALLASnackBar("액션 글자가 길어지면 문구가 먼저 줄어든다.", action: .init("모두 확인했어요") {})
        }
        .padding(.horizontal, SnackBarGalleryMetric.screenMargin)
    }

    /// 배경 opacity 0.77이라 뒤가 비친다 — 단색 위에서만 보면 확인되지 않는다.
    private var onContentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("On Content")
                .padding(.horizontal, SnackBarGalleryMetric.screenMargin)
            galleryCaption("Primary 색 위에 올려 배경 투과 확인")
                .padding(.horizontal, SnackBarGalleryMetric.screenMargin)
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [CHALLAColor.Primary.purple, CHALLAColor.Primary.sky],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 160)
                CHALLASnackBar("셔터를 누르는 순간 장수가 차감돼요.", action: .init("다음") {})
                    .padding(SnackBarGalleryMetric.screenMargin)
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

private enum SnackBarGalleryMetric {
    /// 시안의 스낵바 좌우 여백 (366 = 390 - 12×2)
    static let screenMargin: CGFloat = 12
}

#Preview {
    NavigationStack {
        SnackBarGallery()
    }
}
