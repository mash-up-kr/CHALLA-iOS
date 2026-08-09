import CHALLADesignSystem
import SwiftUI

// TODO: variant `positive`·`cautionary`와 `normal`의 기본 아이콘은 시안에 렌더된 적이 없어 비워 뒀다.
//       디자이너에게 문의해 둔 상태이며, 답변을 받으면 여기에 항목을 추가한다.
struct ToastGallery: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                variantSection
                leadingIconSection
                lengthSection
                onContentSection
            }
            .padding(20)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("Toast")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var variantSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("variant")
            galleryCaption("아이콘 색만 바뀐다 · 배경·글자색은 공통")
            galleryCaption("negative — Status.destructive")
            CHALLAToast(Self.sample, icon: .error, variant: .negative)
        }
    }

    private var leadingIconSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("leadingIcon")
            galleryCaption("icon 지정 — 22pt, 글자와 간격 8")
            CHALLAToast(Self.sample, icon: .error, variant: .negative)
            galleryCaption("icon 생략 — 글자만 (leadingIcon = false)")
            CHALLAToast(Self.sample)
        }
    }

    private var lengthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("문구 길이")
            galleryCaption("짧은 문구 — 내용만큼만 넓어진다")
            CHALLAToast("저장했어요")
            galleryCaption("긴 문구 — 최대 폭 320에서 말줄임")
            CHALLAToast("네트워크 연결이 원활하지 않아 잠시 후 다시 시도해 주세요", icon: .error, variant: .negative)
        }
    }

    private var onContentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("배경 위 (blur 확인)")
            galleryCaption("반투명 + ultraThinMaterial이라 뒤 배경이 비친다")
            ZStack {
                RoundedRectangle(cornerRadius: CHALLARadius.xlarge)
                    .fill(CHALLAColor.Primary.yellow)
                    .frame(height: 120)
                CHALLAToast("사진을 불러오지 못했어요", icon: .error, variant: .negative)
            }
        }
    }

    private static let sample = "마침표를 붙이지 않아요"

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
        ToastGallery()
    }
}
