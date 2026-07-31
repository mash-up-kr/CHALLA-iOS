import CHALLADesignSystem
import SwiftUI

/// Component > Profile Bar 검수 화면.
/// 아바타(사진/placeholder) · 바(9명 이하/초과 +N) · 멤버 팝오버(열기/스크롤/복사)를 나열한다.
/// 사진은 picsum.photos에서 실사진을 받아 주입한다 — 인터넷이 없으면 placeholder만 보인다.
struct ProfileBarGallery: View {

    @State private var isFewPresented = false
    @State private var isManyPresented = false
    @State private var copyCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                avatarSection
                barSection
                popoverSection
            }
            .padding(20)
            // 내용물이 고정 폭이라 ScrollView가 내용 폭만큼만 차지하는 것을 막는다 (CardItemGallery와 동일).
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("Profile Bar")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Avatar 섹션

    /// 사진/placeholder × 크기 2종(바 30, 팝오버 행 20).
    private var avatarSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Avatar")
            galleryCaption("사진 30 · placeholder 30 · 사진 20 · placeholder 20")
            HStack(spacing: 16) {
                sampleImages(seeds: ["face1"]) { CHALLAAvatar(photo: $0.first, size: 30) }
                CHALLAAvatar(photo: nil, size: 30)
                sampleImages(seeds: ["face2"]) { CHALLAAvatar(photo: $0.first, size: 20) }
                CHALLAAvatar(photo: nil, size: 20)
            }
        }
    }

    // MARK: - Bar 섹션

    /// 9명 이하/초과 두 케이스 — 왼쪽 아바타가 위로 겹치는지 확인.
    private var barSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Bar")
            galleryCaption("흰 배경 = 기본(닫힘) 상태 · 열면 검정")
            galleryCaption("3명 — +N 없음")
            sampleImages(seeds: ["m1", "m2", "m3"]) { photos in
                CHALLAProfileBar(
                    members: makeMembers(count: 3, photos: photos),
                    inviteCode: "1928121",
                    isPresented: .constant(false),
                    onCopyInviteCode: {}
                )
            }
            galleryCaption("13명 — 9명 + '+4' 칩")
            sampleImages(seeds: (1...9).map { "m\($0)" }) { photos in
                CHALLAProfileBar(
                    members: makeMembers(count: 13, photos: photos),
                    inviteCode: "1928121",
                    isPresented: .constant(false),
                    onCopyInviteCode: {}
                )
            }
        }
    }

    // MARK: - Popover 섹션

    /// 바를 화면 중앙에 놓는 이유: 팝오버(폭 210)가 바 중앙 기준이라 왼쪽 배치 시 화면 밖으로 잘린다.
    private var popoverSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Popover")
            galleryCaption("바 탭 = 열기 · 바깥 탭 = 닫기 · 복사 콜백 \(copyCount)회")
            galleryCaption("4명 — 내용 높이만큼")
            sampleImages(seeds: ["p1", "p2"]) { photos in
                CHALLAProfileBar(
                    members: makeMembers(count: 4, photos: photos),
                    inviteCode: "1928121",
                    isPresented: $isFewPresented,
                    onCopyInviteCode: { copyCount += 1 }
                )
            }
            .frame(maxWidth: .infinity)
            // 열린 팝오버가 뒤(아래)에 선언된 형제 뷰에 가려지지 않게 띄운다.
            .zIndex(isFewPresented ? 1 : 0)
            galleryCaption("13명 — 최대 450에서 잘리고 리스트 스크롤")
            sampleImages(seeds: (1...9).map { "m\($0)" }) { photos in
                CHALLAProfileBar(
                    members: makeMembers(count: 13, photos: photos),
                    inviteCode: "1928121",
                    isPresented: $isManyPresented,
                    onCopyInviteCode: { copyCount += 1 }
                )
            }
            .frame(maxWidth: .infinity)
            .zIndex(isManyPresented ? 1 : 0)
            // 팝오버(최대 450 + 간격)가 화면 밖으로 잘리지 않도록 스크롤 공간 확보.
            Color.clear.frame(height: 500)
        }
        // 실제 화면엔 ProfileBar가 하나뿐이다 — 갤러리에서 두 팝오버가 동시에 열려
        // 겹치지 않도록, 하나가 열리면 다른 하나를 닫는다.
        .onChange(of: isFewPresented) { _, isOpen in
            if isOpen { isManyPresented = false }
        }
        .onChange(of: isManyPresented) { _, isOpen in
            if isOpen { isFewPresented = false }
        }
    }

    // MARK: - 공통 헬퍼

    /// 앞쪽 멤버는 받은 사진을 쓰고, 모자라면 placeholder(nil).
    private func makeMembers(count: Int, photos: [Image]) -> [CHALLAProfileBar.Member] {
        (0..<count).map { index in
            CHALLAProfileBar.Member(
                id: "\(index)",
                name: sampleNames[index % sampleNames.count],
                avatar: index < photos.count ? photos[index] : nil
            )
        }
    }

    private let sampleNames = [
        "부리부리자에몽", "멋쟁이 토마토", "해피하우스", "아이스크림",
        "다람쥐가방에들어가심", "네가지치즈불닭", "사리곰탕면", "꿀아메리카노", "엄성현",
    ]

    /// picsum 실사진 여러 장을 받아 뷰에 주입한다 (PrintCardGallery와 같은 방식 — 정사각 100px).
    private func sampleImages(
        seeds: [String],
        @ViewBuilder content: @escaping ([Image]) -> some View
    ) -> some View {
        SampleImagesLoader(seeds: seeds, content: content)
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

/// [Image]가 필요한 뷰용 로더 — AsyncImage는 한 장씩만 다뤄서 직접 받는다.
/// 로딩 전에는 사진 없는 상태(placeholder 아바타)로 먼저 그린다.
private struct SampleImagesLoader<Content: View>: View {
    let seeds: [String]
    @ViewBuilder let content: ([Image]) -> Content

    @State private var images: [Image] = []

    var body: some View {
        content(images)
            .task {
                var loaded: [Image] = []
                for seed in seeds {
                    let url = URL(string: "https://picsum.photos/seed/\(seed)/100")!
                    guard let (data, _) = try? await URLSession.shared.data(from: url),
                          let uiImage = UIImage(data: data) else { continue }
                    loaded.append(Image(uiImage: uiImage))
                }
                images = loaded
            }
    }
}

#Preview {
    NavigationStack {
        ProfileBarGallery()
    }
}
