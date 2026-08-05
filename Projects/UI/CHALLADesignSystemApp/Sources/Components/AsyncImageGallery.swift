import CHALLADesignSystem
import SwiftUI

/// Component > AsyncImage 검수 화면.
/// 기본형·커스텀형·실패·그리드 4가지 상태를 나열한다. 이미지는 picsum(시드 고정) 사용.
struct AsyncImageGallery: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                basicSection
                customSection
                failureSection
                gridSection
            }
            .padding(20)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("AsyncImage")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 기본형 — URL만 넘기면 DS 배경 박스 → 완료 시 페이드인.
    private var basicSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("기본형")
            galleryCaption("CHALLAAsyncImage(url:) — 로딩 중 DS 박스, 완료 시 페이드인")
            CHALLAAsyncImage(url: URL(string: "https://picsum.photos/seed/challa-basic/800/800"))
                .scaledToFill()
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: CHALLARadius.medium))
        }
    }

    /// 커스텀형 — content·placeholder를 호출부가 지정.
    private var customSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("커스텀형")
            galleryCaption("content·placeholder 클로저 지정 (로딩 중 스피너)")
            CHALLAAsyncImage(url: URL(string: "https://picsum.photos/seed/challa-custom/800/500")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    CHALLAColor.Background.level3
                    ProgressView()
                }
            }
            .frame(width: 240, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: CHALLARadius.medium))
        }
    }

    /// 실패 — 존재하지 않는 이미지(404). 별도 실패 UI 없이 placeholder가 유지되는지 검수.
    /// (404는 재시도 대상이 아니라 즉시 실패한다 — 없는 도메인이면 재시도 백오프로 7초 걸림)
    private var failureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("실패")
            galleryCaption("404 URL — placeholder(DS 박스) 유지가 정상")
            CHALLAAsyncImage(url: URL(string: "https://picsum.photos/id/99999/400/400"))
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: CHALLARadius.medium))
        }
    }

    /// 그리드 — 방 상세와 같은 실전 배치. 셀 크기에 맞는 다운샘플·스크롤 캐시 동작 검수.
    private var gridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("그리드")
            galleryCaption("셀 9장 — 스크롤로 나갔다 돌아오면 캐시에서 즉시 표시")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<9, id: \.self) { index in
                    CHALLAAsyncImage(url: URL(string: "https://picsum.photos/seed/challa-grid-\(index)/600/600"))
                        .scaledToFill()
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: CHALLARadius.small))
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
        AsyncImageGallery()
    }
}
