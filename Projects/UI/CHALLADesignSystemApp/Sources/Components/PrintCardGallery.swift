import CHALLADesignSystem
import SwiftUI

/// Component > Print Card 검수 화면.
/// 인화 카드의 상태 2종(인화 대기/완료)과 사진 장수 엣지 케이스를 나열한다.
/// 사진은 picsum.photos에서 실사진을 받아 주입한다 — 인터넷이 없으면 로딩 자리만 남는다.
struct PrintCardGallery: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                statusSection
                countSection
            }
            .padding(20)
            // 내용물이 고정 폭이라 ScrollView가 내용 폭만큼만 차지하는 것을 막는다 (CardItemGallery와 동일).
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("Print Card")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Status 섹션

    /// 상태 2종 검수 — 칩 색과 낱장 blur/선명이 함께 바뀌는지 확인.
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Status")
            galleryCaption("인화 대기 (칩 회색톤 · 낱장 blur)")
            samplePhotosCard(seeds: ["p1", "p2", "p3", "p4"]) {
                CHALLAPrintCard(status: .printing, title: "친구들과 강릉 여행",
                                memberCount: 11, photos: $0, totalPhotoCount: 24)
            }
            galleryCaption("인화 완료 (칩 노랑톤 · 낱장 선명)")
            samplePhotosCard(seeds: ["p1", "p2", "p3", "p4"]) {
                CHALLAPrintCard(status: .printed, title: "인화 완료 된 방이에요",
                                memberCount: 11, photos: $0, totalPhotoCount: 24)
            }
        }
    }

    // MARK: - Photo Count 섹션

    /// 사진 장수 엣지 검수 — 전체 4장 이하(+N 없음), 슬롯보다 적을 때(빈 슬롯).
    private var countSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Photo Count")
            galleryCaption("전체 4장 — 마지막 슬롯도 일반 낱장 (+N 없음)")
            samplePhotosCard(seeds: ["p1", "p2", "p3", "p4"]) {
                CHALLAPrintCard(status: .printed, title: "딱 네 장 찍은 방",
                                memberCount: 4, photos: $0, totalPhotoCount: 4)
            }
            galleryCaption("전체 2장 — 뒤 슬롯 비움 (시안 없음 · 디자이너 확인 예정)")
            samplePhotosCard(seeds: ["p1", "p2"]) {
                CHALLAPrintCard(status: .printed, title: "두 장뿐인 방",
                                memberCount: 2, photos: $0, totalPhotoCount: 2)
            }
        }
    }

    // MARK: - 공통 헬퍼

    /// picsum 실사진 여러 장을 받아 카드에 주입한다. seed가 같으면 같은 사진이 온다.
    /// 전부 로드될 때까지 스트립 높이만큼 자리를 잡아 레이아웃이 튀지 않게 한다.
    private func samplePhotosCard(
        seeds: [String],
        @ViewBuilder makeCard: @escaping ([Image]) -> CHALLAPrintCard
    ) -> some View {
        SamplePhotosLoader(seeds: seeds, makeCard: makeCard)
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

/// 사진 여러 장이 필요한 카드용 로더.
/// AsyncImage는 한 장씩만 다뤄서 [Image]를 만들 수 없으므로 URLSession으로 직접 받는다.
private struct SamplePhotosLoader: View {
    let seeds: [String]
    @ViewBuilder let makeCard: ([Image]) -> CHALLAPrintCard

    @State private var photos: [Image] = []

    var body: some View {
        Group {
            if photos.count == seeds.count {
                makeCard(photos)
            } else {
                RoundedRectangle(cornerRadius: CHALLARadius.medium)
                    .fill(CHALLAColor.Background.level2)
                    .frame(height: 196) // 헤더(~66) + 스트립(130) 근사 높이
            }
        }
        .task {
            var loaded: [Image] = []
            for seed in seeds {
                guard let url = URL(string: "https://picsum.photos/seed/\(seed)/300/400"),
                      let (data, _) = try? await URLSession.shared.data(from: url),
                      let uiImage = UIImage(data: data) else { continue }
                loaded.append(Image(uiImage: uiImage))
            }
            photos = loaded
        }
    }
}

#Preview {
    NavigationStack {
        PrintCardGallery()
    }
}
