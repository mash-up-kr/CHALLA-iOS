import CHALLADesignSystem
import SwiftUI

/// Component > Room Card 검수 화면.
/// 방 카드의 상태 3종(촬영 중 · 인화 대기 · 인화 완료) × 사진 유무 · 제목 길이 · 액션 유무 조합을 나열한다.
/// 사진은 picsum.photos에서 실사진을 받아 주입한다 — 인터넷이 없으면 로딩 자리만 남는다.
struct RoomCardGallery: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                photoSection
                textSection
                shootSection
                printWaitingSection
                printedSection
            }
            .padding(20)
            // 내용물이 전부 고정 폭(카드 200 등)이라 그대로 두면 ScrollView가 내용 폭만큼만
            // 차지해 배경이 화면을 못 채운다 — 가로 제안을 전부 받게 해 끝까지 깔리게 한다.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("Room Card")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Photo 섹션

    /// 사진 유무 검수 — 딤 그라데이션 위 글자 가독성과 사진 없는 바닥색 확인.
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Photo")
            galleryCaption("사진 있음 (딤 그라데이션 확인)")
            samplePhotoCard(seed: "room1") {
                CHALLARoomCard(
                    title: "친구들과 강릉 여행",
                    memberCount: 11,
                    photo: $0,
                    variant: .shooting(isPreparing: false, onShoot: nil)
                )
            }
            galleryCaption("사진 없음 (photo: nil — 로딩 전·사진 없는 방)")
            CHALLARoomCard(
                title: "이제 막 만든 방",
                memberCount: 1,
                photo: nil,
                variant: .shooting(isPreparing: false, onShoot: nil)
            )
        }
    }

    // MARK: - Text 섹션

    /// 제목 길이·숫자 자릿수 검수 — 줄바꿈과 뱃지 폭 변화 확인.
    private var textSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Text")
            galleryCaption("긴 제목 (줄바꿈)")
            samplePhotoCard(seed: "room2") {
                CHALLARoomCard(
                    title: "동아리 엠티에서 찍은 사진 다 모아두는 방",
                    memberCount: 10,
                    photo: $0,
                    variant: .shooting(isPreparing: false, onShoot: nil)
                )
            }
        }
    }

    // MARK: - Shoot 섹션

    /// 촬영 뱃지 검수 — 액션이 없을 때(그림)와 있을 때(버튼), 준비 중 스피너를 나란히 본다.
    private var shootSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Shoot")
            galleryCaption("액션 없음 — 눌리지 않는 그림")
            CHALLARoomCard(
                title: "촬영 버튼 없는 방",
                memberCount: 4,
                photo: nil,
                variant: .shooting(isPreparing: false, onShoot: nil)
            )
            galleryCaption("액션 있음 — 뱃지가 촬영 버튼이 된다")
            CHALLARoomCard(
                title: "촬영 가능한 방",
                memberCount: 4,
                photo: nil,
                variant: .shooting(isPreparing: false, onShoot: {})
            )
            galleryCaption("준비 중 — 목록·권한을 받는 동안 스피너, 다시 눌리지 않는다")
            CHALLARoomCard(
                title: "촬영 준비 중인 방",
                memberCount: 4,
                photo: nil,
                variant: .shooting(isPreparing: true, onShoot: {})
            )
        }
    }

    // MARK: - Print Waiting 섹션

    /// 인화 대기 뱃지 검수 — 사진 위 어두운 뱃지 대비, 남은 시간 자릿수별 뱃지 폭 확인.
    private var printWaitingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Print Waiting")
            galleryCaption("사진 있음 — 딤 위 시계 뱃지 대비")
            samplePhotoCard(seed: "room3") {
                CHALLARoomCard(
                    title: "친구들과 유럽 여행",
                    memberCount: 5,
                    photo: $0,
                    variant: .printWaiting(remainingTime: "2:15:32")
                )
            }
            galleryCaption("자릿수 최대(23:59:59) — 뱃지 폭이 제일 넓어지는 경우")
            CHALLARoomCard(
                title: "방금 대기로 넘어간 방",
                memberCount: 5,
                photo: nil,
                variant: .printWaiting(remainingTime: "23:59:59")
            )
            galleryCaption("자릿수 최소(0:00:01) — 곧 완료로 넘어가기 직전")
            CHALLARoomCard(
                title: "곧 인화가 끝나는 방",
                memberCount: 5,
                photo: nil,
                variant: .printWaiting(remainingTime: "0:00:01")
            )
        }
    }

    // MARK: - Printed 섹션

    /// 확인하기 버튼 검수 — 테마색 글로우 세기, 액션 유무(버튼/그림) 확인.
    private var printedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Printed")
            galleryCaption("액션 있음 — 확인하기 버튼 + 노랑 글로우")
            samplePhotoCard(seed: "room4") {
                CHALLARoomCard(
                    title: "친구들과 유럽 여행",
                    memberCount: 5,
                    photo: $0,
                    variant: .printed(onConfirm: {})
                )
            }
            galleryCaption("액션 없음 — 버튼 모양의 그림 (눌리지 않는 자리용)")
            CHALLARoomCard(
                title: "인화 완료된 방",
                memberCount: 5,
                photo: nil,
                variant: .printed(onConfirm: nil)
            )
        }
    }

    // MARK: - 공통 헬퍼

    /// picsum 실사진을 받아 카드에 주입한다. seed가 같으면 같은 사진이 온다.
    /// 로딩 중에도 카드와 같은 크기(200×266)로 자리를 잡아 레이아웃이 튀지 않게 한다.
    private func samplePhotoCard(
        seed: String,
        @ViewBuilder makeCard: @escaping (Image) -> CHALLARoomCard
    ) -> some View {
        AsyncImage(url: URL(string: "https://picsum.photos/seed/\(seed)/400/532")) { photo in
            makeCard(photo)
        } placeholder: {
            RoundedRectangle(cornerRadius: CHALLARadius.large)
                .fill(CHALLAColor.Background.level2)
                .frame(width: 200, height: 266)
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
        RoomCardGallery()
    }
}
