import SwiftUI

/// 디자인 시스템 인화 완료 카드.
/// 홈 하단 "인화 완료" 목록에서 방 하나를 나타내며, 방 제목·인원 아래에
/// 필름 낱장들이 기울어져 겹친 스택이 놓인다.
/// 인화 대기 상태 표현(칩·blur)은 2차 시안에서 상단 방 카드(``CHALLARoomCard``)로
/// 옮겨가서, 이 카드는 완료된 방만 그린다 — 낱장은 항상 선명하고 마지막 "+N"만 blur다.
///
/// 사진은 URL 또는 이미 로드된 `Image` 배열로 받는다. URL을 넘기면 낱장마다
/// ``CHALLAAsyncImage``가 자기 슬롯 크기로 로드하고, 로드 전에는 빈 낱장을 그린다.
/// 탭 동작은 호출부가 Button 등으로 감싼다.
///
/// ```swift
/// // 화면 — URL을 넘긴다
/// CHALLAPrintCard(title: "친구들과 강릉 여행",
///                 memberCount: 11, photoURLs: room.thumbnailURLs, totalPhotoCount: 24)
///
/// // 갤러리·Preview — 번들 이미지를 넘긴다
/// CHALLAPrintCard(title: "친구들과 강릉 여행",
///                 memberCount: 11, photos: samples, totalPhotoCount: 24)
/// ```
public struct CHALLAPrintCard: View {

    // MARK: - 프로퍼티와 init

    /// 낱장에 넣을 사진의 출처.
    ///
    /// 화면은 URL을, 갤러리·Preview는 번들 이미지를 쓴다.
    /// 검수는 네트워크 없이 그려야 해서 두 경로가 함께 필요하다.
    private enum PhotoSource {
        case images([Image])
        case urls([URL])

        /// 슬롯에 놓을 수 있는 사진 수.
        var count: Int {
            switch self {
            case let .images(images): return images.count
            case let .urls(urls): return urls.count
            }
        }
    }

    private let title: String
    private let memberCount: Int
    private let source: PhotoSource
    private let totalPhotoCount: Int

    /// - Parameters:
    ///   - title: 방 이름.
    ///   - memberCount: 참여 인원 수.
    ///   - photoURLs: 표시할 사진 URL — 앞에서부터 슬롯 4칸에 배치하며 초과분은 버린다.
    ///     4칸보다 적으면 있는 만큼만 놓는다 (시안 없음 — 디자이너 확인 예정).
    ///   - totalPhotoCount: 방의 전체 장수. 4장을 넘으면 마지막 슬롯이 "+N"이 된다.
    public init(
        title: String,
        memberCount: Int,
        photoURLs: [URL],
        totalPhotoCount: Int
    ) {
        self.title = title
        self.memberCount = memberCount
        self.source = .urls(photoURLs)
        self.totalPhotoCount = totalPhotoCount
    }

    /// 로드된 이미지를 직접 넘기는 생성자 — 검수앱 갤러리·Preview·테스트용.
    ///
    /// - Parameters:
    ///   - photos: 표시할 사진. 배치 규칙은 URL 생성자와 같다.
    public init(
        title: String,
        memberCount: Int,
        photos: [Image],
        totalPhotoCount: Int
    ) {
        self.title = title
        self.memberCount = memberCount
        self.source = .images(photos)
        self.totalPhotoCount = totalPhotoCount
    }

    // MARK: - 표기 규칙

    /// 전체 장수가 슬롯 수를 넘을 때 마지막 슬롯에 표시할 "+N" 값. 넘지 않으면 nil.
    /// 슬롯 4칸 중 사진 3칸 + 더보기 1칸이 되므로 N = 전체 - 3.
    /// (홈 시안 예: 전체 24장 → 사진 3장 + "+21")
    /// 순수 계산이라 MainActor 격리가 불필요하다 (ProfileBar.overflowCount와 같은 이유).
    nonisolated static func overflowCount(totalPhotoCount: Int) -> Int? {
        let slotCount = PrintCardMetric.slots.count
        guard totalPhotoCount > slotCount else { return nil }
        return totalPhotoCount - (slotCount - 1)
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: PrintCardMetric.headerStripGap) {
            header
            strip
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - 헤더 (제목·인원)

    private var header: some View {
        HStack {
            Text(title)
                .challaFont(.body.large.bold)
                .foregroundStyle(CHALLAColor.Label.normal)
            Spacer(minLength: 0)
            memberRow
        }
    }

    private var memberRow: some View {
        HStack(spacing: PrintCardMetric.memberIconGap) {
            CHALLAIcon.person.image(size: .size18, color: CHALLAColor.Label.subtle)
            Text("\(memberCount)")
                .challaFont(.body.small.bold)
                .foregroundStyle(CHALLAColor.Label.subtle)
        }
    }

    // MARK: - 낱장 스택

    /// 낱장 4칸을 시안 실측 좌표·회전각에 고정 배치한다.
    /// 폭은 부모 제안을 받아 늘어나되 좌표가 leading 기준이라 스택 자체는 왼쪽에 머문다.
    private var strip: some View {
        ZStack {
            ForEach(Array(PrintCardMetric.slots.enumerated()), id: \.offset) { index, slot in
                if index < source.count {
                    slotFilm(at: index)
                        .rotationEffect(.degrees(slot.angle))
                        .position(slot.center)
                }
            }
        }
        .frame(height: PrintCardMetric.stripHeight)
        .frame(maxWidth: .infinity)
    }

    /// 슬롯 한 칸의 낱장. URL이면 로드될 때까지 빈 낱장을 그려 자리를 잡는다.
    @ViewBuilder
    private func slotFilm(at index: Int) -> some View {
        switch source {
        case let .images(images):
            filmCard(photo: images[index], at: index)
        case let .urls(urls):
            CHALLAAsyncImage(url: urls[index]) { image in
                filmCard(photo: image, at: index)
            } placeholder: {
                CHALLAFilmCard(variant: .beforeCapture, width: PrintCardMetric.filmWidth)
            }
        }
    }

    /// 사진 한 장을 슬롯 규칙에 맞는 낱장으로 만든다.
    /// 마지막 슬롯은 전체 장수가 넘칠 때 "+N"이 된다 — 이 슬롯만 blur (시안 스펙).
    private func filmCard(photo: Image, at index: Int) -> CHALLAFilmCard {
        let isLastSlot = index == PrintCardMetric.slots.count - 1
        if isLastSlot, let overflow = Self.overflowCount(totalPhotoCount: totalPhotoCount) {
            return CHALLAFilmCard(variant: .more(photo: photo, count: overflow), width: PrintCardMetric.filmWidth)
        }
        return CHALLAFilmCard(variant: .printed(photo: photo), width: PrintCardMetric.filmWidth)
    }

    /// VoiceOver가 읽을 한 문장.
    private var accessibilityDescription: String {
        "\(title), 인화 완료, \(memberCount)명 참여, 사진 \(totalPhotoCount)장"
    }
}

// MARK: - Figma 실측값

private enum PrintCardMetric {
    /// 낱장 슬롯의 중심 좌표(358×130 캔버스 기준)와 회전각.
    /// 마지막 슬롯(더보기)만 똑바로 놓인다.
    struct Slot {
        let center: CGPoint
        let angle: Double
    }

    static let slots: [Slot] = [
        Slot(center: CGPoint(x: 56.1, y: 65.8), angle: -5.05),
        Slot(center: CGPoint(x: 139.9, y: 64.3), angle: 5.85),
        Slot(center: CGPoint(x: 223.5, y: 65.3), angle: -5.99),
        Slot(center: CGPoint(x: 306.7, y: 64.2), angle: 0)
    ]

    /// 홈 스트립의 낱장 폭 (검수 기본 82와 다른 실측값 — 세로 120은 FilmCard가 계산).
    static let filmWidth: CGFloat = 90
    /// 낱장 스택 캔버스 높이 (회전 여유 포함).
    static let stripHeight: CGFloat = 130
    /// 헤더와 스택 사이 간격.
    static let headerStripGap: CGFloat = 14
    /// person 아이콘과 인원 숫자 사이 간격.
    static let memberIconGap: CGFloat = 2
}

#Preview {
    // 실사진 로딩은 갤러리에서 검수한다 — 프리뷰는 배치·+N 확인용 심볼 이미지.
    let samples = [Image(systemName: "photo"), Image(systemName: "photo"),
                   Image(systemName: "photo"), Image(systemName: "photo")]

    VStack(alignment: .leading, spacing: 32) {
        CHALLAPrintCard(title: "친구들과 강릉 여행",
                        memberCount: 11, photos: samples, totalPhotoCount: 24)
        CHALLAPrintCard(title: "딱 네 장 찍은 방",
                        memberCount: 11, photos: samples, totalPhotoCount: 4)
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CHALLAColor.Background.surface)
}
