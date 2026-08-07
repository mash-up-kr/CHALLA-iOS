import CHALLADesignSystem
import SwiftUI

/// Component > AsyncImage 검수 화면.
/// 실제 DS 컴포넌트(FilmCard·CardItem·Avatar)에 CHALLAAsyncImage를 물려,
/// 찰나 화면과 같은 조합으로 로딩·실패·캐시 동작을 검수한다. 이미지는 picsum(시드 고정) 사용.
struct AsyncImageGallery: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                basicSection
                filmSection
                cardSection
                avatarSection
                failureSection
                gridSection
            }
            .padding(20)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("AsyncImage")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 기본형 — 컴포넌트 조합 없이 URL만 넘기는 최소 사용법. DS 박스 → 페이드인.
    private var basicSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("기본형")
            galleryCaption("CHALLAAsyncImage(url:) — 로딩 중 DS 박스, 완료 시 페이드인")
            CHALLAAsyncImage(url: URL(string: "https://picsum.photos/seed/challa-basic/600/800"))
                .scaledToFill()
                .frame(width: 90, height: 90 / CHALLAFilmCard.aspectRatio)
                .clipShape(RoundedRectangle(cornerRadius: CHALLARadius.medium))
        }
    }

    /// 필름 낱장 — CHALLAFilmCard에 로드된 사진을 꽂는 실전 조합.
    /// 로딩 중에는 촬영 전(dashed) 카드가 자리를 지키고, 완료되면 인화완료/인화대기 카드가 된다.
    private var filmSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("필름 낱장 — CHALLAFilmCard")
            galleryCaption("홈 82 · 인화 90(인화완료) · 인화대기(blur) — 로딩 중엔 dashed 카드")
            HStack(alignment: .top, spacing: 16) {
                filmCell(width: 82, seed: "challa-film-home")
                filmCell(width: 90, seed: "challa-film-print")
                CHALLAAsyncImage(url: URL(string: "https://picsum.photos/seed/challa-film-blur/600/800")) { image in
                    CHALLAFilmCard(variant: .printing(photo: image), width: 90)
                } placeholder: {
                    CHALLAFilmCard(variant: .beforeCapture, width: 90)
                }
            }
        }
    }

    /// 방 카드 — CHALLACardItem의 대표 사진 자리에 연결. photo가 nil이면 카드가 바닥색을 그린다.
    private var cardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("방 카드 — CHALLACardItem")
            galleryCaption("로딩 중엔 photo: nil 카드(바닥색), 완료되면 대표 사진이 페이드인")
            CHALLAAsyncImage(url: URL(string: "https://picsum.photos/seed/challa-card/800/1064")) { image in
                CHALLACardItem(title: "찰나 모임", memberCount: 4, photoCount: 12, photo: image)
            } placeholder: {
                CHALLACardItem(title: "찰나 모임", memberCount: 4, photoCount: 12, photo: nil)
            }
        }
    }

    /// 아바타 — CHALLAAvatar 실측 지름 3종. photo가 nil이면 person placeholder가 나온다.
    /// 셋이 같은 URL을 쓰므로 "같은 사진, 다른 표시 크기 = 별도 캐시 항목" 정책도 함께 확인된다.
    private var avatarSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("아바타 — CHALLAAvatar")
            galleryCaption("실측 지름 30 · 22 · 20 — 초소형 타깃에서도 또렷한지 검수")
            HStack(alignment: .center, spacing: 16) {
                avatarCell(diameter: 30)
                avatarCell(diameter: 22)
                avatarCell(diameter: 20)
            }
        }
    }

    /// 실패 — 존재하지 않는 이미지(404). 실패 UI 없이 placeholder(dashed 카드)가 유지되는지 검수.
    /// (404는 재시도 대상이 아니라 즉시 실패한다 — 없는 도메인이면 재시도 백오프로 7초 걸림)
    private var failureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("실패")
            galleryCaption("404 URL — dashed 카드(placeholder) 유지가 정상")
            CHALLAAsyncImage(url: URL(string: "https://picsum.photos/id/99999/400/400")) { image in
                CHALLAFilmCard(variant: .printed(photo: image), width: 90)
            } placeholder: {
                CHALLAFilmCard(variant: .beforeCapture, width: 90)
            }
        }
    }

    /// 방 상세 그리드 — FilmCard를 3열로 배치한 실전 레이아웃. width nil이라 셀 폭을 채운다.
    private var gridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("방 상세 그리드 — CHALLAFilmCard × 3열")
            galleryCaption("셀 9장, 순번 표시 — 스크롤로 나갔다 돌아오면 캐시에서 즉시 표시")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0 ..< 9, id: \.self) { index in
                    CHALLAAsyncImage(url: URL(string: "https://picsum.photos/seed/challa-grid-\(index)/600/800")) { image in
                        CHALLAFilmCard(variant: .printed(photo: image), slotNumber: index + 1)
                    } placeholder: {
                        CHALLAFilmCard(variant: .beforeCapture, slotNumber: index + 1)
                    }
                }
            }
        }
    }

    // MARK: - 셀 헬퍼

    /// 인화완료 필름 카드 조합 셀 — 로딩 중엔 촬영 전(dashed) 카드가 자리를 지킨다.
    private func filmCell(width: CGFloat, seed: String) -> some View {
        CHALLAAsyncImage(url: URL(string: "https://picsum.photos/seed/\(seed)/600/800")) { image in
            CHALLAFilmCard(variant: .printed(photo: image), width: width)
        } placeholder: {
            CHALLAFilmCard(variant: .beforeCapture, width: width)
        }
    }

    /// 아바타 조합 셀 — 셋이 같은 URL을 써서 크기별 캐시 분리를 확인한다.
    private func avatarCell(diameter: CGFloat) -> some View {
        CHALLAAsyncImage(url: URL(string: "https://picsum.photos/seed/challa-avatar/300/300")) { image in
            CHALLAAvatar(photo: image, size: diameter)
        } placeholder: {
            CHALLAAvatar(photo: nil, size: diameter)
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
