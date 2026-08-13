import CHALLADesignSystem
import SwiftUI

/// Component > Photo Count Selector 검수 화면.
/// 선택 위치 3가지 · 장수 구성 2가지 · 선택 없음을 나열한다.
struct PhotoCountSelectorGallery: View {

    @State private var selected = 24

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                interactiveSection
                staticSection
            }
            .padding(20)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("Photo Count Selector")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var interactiveSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("탭해서 선택 (방 만들기 구성)")
            CHALLAPhotoCountSelector(counts: [24, 48, 72], selected: selected) {
                selected = $0
            }
        }
    }

    private var staticSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("선택 위치별")
            CHALLAPhotoCountSelector(counts: [24, 48, 72], selected: 24, onSelect: { _ in })
            CHALLAPhotoCountSelector(counts: [24, 48, 72], selected: 48, onSelect: { _ in })
            CHALLAPhotoCountSelector(counts: [24, 48, 72], selected: 72, onSelect: { _ in })
            galleryTitle("장수 2개 구성")
            CHALLAPhotoCountSelector(counts: [24, 48], selected: 24, onSelect: { _ in })
            // selected가 counts에 없는 값일 때. 아직 고르지 않은 화면이 생기면 이 모습이 된다.
            galleryTitle("선택 없음")
            CHALLAPhotoCountSelector(counts: [24, 48, 72], selected: 0, onSelect: { _ in })
        }
    }

    private func galleryTitle(_ text: String) -> some View {
        Text(text)
            .challaFont(.body.large.bold)
            .foregroundStyle(CHALLAColor.Label.strong)
    }
}

#Preview {
    NavigationStack {
        PhotoCountSelectorGallery()
    }
}
