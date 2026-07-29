import CHALLADesignSystem
import SwiftUI

/// Component > Film Card 검수 화면.
/// Figma Type 4종(촬영 전/인화대기/인화완료/더보기) × 필름 숫자 순서, 그리고 폭 대응을 나열한다.
/// 사진은 picsum.photos에서 실사진을 받아 주입한다 — 샘플 이미지를 저장소에 커밋하지 않기 위함이며,
/// 인터넷이 없으면 로딩 자리만 남는다 (검수앱 한정 트레이드오프).
struct FilmCardGallery: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                typeSection
                slotNumberSection
                widthSection
            }
            .padding(20)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("Film Card")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Type 4종 검수 — 시안 기본 폭(82) 고정.
    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Type")
            galleryCaption("촬영 전 · 인화대기 · 인화완료 · 더보기(+21)")
            // 82pt 4장 + 간격이 작은 기기 폭을 넘어서므로 가로 스크롤로 감싼다.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    CHALLAFilmCard(variant: .beforeCapture, slotNumber: 1, width: 82)
                    samplePhotoCard(seed: "printing", width: 82) {
                        CHALLAFilmCard(variant: .printing(photo: $0), slotNumber: 2, width: 82)
                    }
                    samplePhotoCard(seed: "printed", width: 82) {
                        CHALLAFilmCard(variant: .printed(photo: $0), slotNumber: 3, width: 82)
                    }
                    samplePhotoCard(seed: "more", width: 82) {
                        CHALLAFilmCard(variant: .more(photo: $0, count: 21), width: 82)
                    }
                }
            }
        }
    }

    /// 필름 숫자 순서 true/false 검수 (Figma Bool 속성).
    private var slotNumberSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("필름 숫자 순서")
            galleryCaption("slotNumber 있음(왼쪽) / nil(오른쪽)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    CHALLAFilmCard(variant: .beforeCapture, slotNumber: 2, width: 82)
                    CHALLAFilmCard(variant: .beforeCapture, width: 82)
                    samplePhotoCard(seed: "printed", width: 82) {
                        CHALLAFilmCard(variant: .printed(photo: $0), slotNumber: 2, width: 82)
                    }
                    samplePhotoCard(seed: "printed", width: 82) {
                        CHALLAFilmCard(variant: .printed(photo: $0), width: 82)
                    }
                }
            }
        }
    }

    /// 폭 대응 검수 — width를 넘기지 않으면 그리드가 나눠준 폭을 그대로 채운다 (방 상세 시뮬레이션).
    /// 기기·회전을 바꿔가며 낱장이 3:4를 유지하는지, 순번·+N이 어색하지 않은지 확인한다.
    private var widthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Width")
            galleryCaption("4열 그리드 — 폭 자동 할당 (width: nil)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                samplePhotoCard(seed: "grid1", width: nil) {
                    CHALLAFilmCard(variant: .printed(photo: $0), slotNumber: 1)
                }
                samplePhotoCard(seed: "grid2", width: nil) {
                    CHALLAFilmCard(variant: .printing(photo: $0), slotNumber: 2)
                }
                CHALLAFilmCard(variant: .beforeCapture, slotNumber: 3)
                CHALLAFilmCard(variant: .beforeCapture, slotNumber: 4)
            }
        }
    }

    /// picsum 실사진을 받아 낱장에 주입한다. seed가 같으면 같은 사진이 온다.
    /// 로딩 중에도 낱장과 같은 크기 규칙의 자리를 잡아 레이아웃이 튀지 않게 한다.
    private func samplePhotoCard(
        seed: String,
        width: CGFloat?,
        @ViewBuilder makeCard: @escaping (Image) -> CHALLAFilmCard
    ) -> some View {
        AsyncImage(url: URL(string: "https://picsum.photos/seed/\(seed)/300/400")) { photo in
            makeCard(photo)
        } placeholder: {
            let shape = RoundedRectangle(cornerRadius: CHALLARadius.medium)
                .fill(CHALLAColor.Background.level2)
            if let width {
                shape.frame(width: width, height: width / CHALLAFilmCard.aspectRatio)
            } else {
                shape.aspectRatio(CHALLAFilmCard.aspectRatio, contentMode: .fit)
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
        FilmCardGallery()
    }
}
