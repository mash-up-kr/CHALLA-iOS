import CHALLADesignSystem
import SwiftUI

/// Component > Top Navigation 검수 화면.
/// Figma 예시 6조합을 전수 나열한다: main(기본/우측 아이콘), sub(없음/왼쪽/오른쪽/양쪽).
struct TopNavigationGallery: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                mainSection
                subSection
            }
            .padding(.vertical, 20)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("Top Navigation")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// main variant: 홈 로고 고정, 우측 아이콘 유무 2조합.
    private var mainSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Main")
            galleryCaption("기본")
            CHALLATopNavigation.main()
            galleryCaption("trailing 아이콘")
            CHALLATopNavigation.main(
                trailing: .icon(.setting, accessibilityLabel: "설정") {}
            )
        }
    }

    /// sub variant: 중앙 타이틀 고정, 좌우 아이콘 4조합.
    private var subSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Sub")
            galleryCaption("기본")
            CHALLATopNavigation.sub(title: "타이틀")
            galleryCaption("leading 아이콘")
            CHALLATopNavigation.sub(
                title: "타이틀",
                leading: .icon(.caretLeft, accessibilityLabel: "뒤로 가기") {}
            )
            galleryCaption("trailing 아이콘")
            CHALLATopNavigation.sub(
                title: "타이틀",
                trailing: .icon(.close, accessibilityLabel: "닫기") {}
            )
            galleryCaption("leading + trailing")
            CHALLATopNavigation.sub(
                title: "타이틀",
                leading: .icon(.caretLeft, accessibilityLabel: "뒤로 가기") {},
                trailing: .icon(.close, accessibilityLabel: "닫기") {}
            )
            galleryCaption("긴 타이틀 (말줄임·슬롯 회피 확인)")
            CHALLATopNavigation.sub(
                title: "아주아주 길어서 한 줄에 안 들어가는 타이틀",
                leading: .icon(.caretLeft, accessibilityLabel: "뒤로 가기") {},
                trailing: .icon(.close, accessibilityLabel: "닫기") {}
            )
        }
    }

    private func galleryTitle(_ text: String) -> some View {
        Text(text)
            .challaFont(.body.large.bold)
            .foregroundStyle(CHALLAColor.Label.strong)
            .padding(.horizontal, 20)
    }

    private func galleryCaption(_ text: String) -> some View {
        Text(text)
            .challaFont(.body.xsmall.bold)
            .foregroundStyle(CHALLAColor.Label.alternative)
            .padding(.horizontal, 20)
    }
}

#Preview {
    NavigationStack {
        TopNavigationGallery()
    }
}
