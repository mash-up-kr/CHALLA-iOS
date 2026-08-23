import SwiftUI

/// 디자인 시스템 방 카드.
/// 방 대표 사진 위에 딤 그라데이션을 깔고 제목·인원을 겹쳐 보여주며,
/// 하단 요소는 방 상태(`Variant`)에 따라 갈린다 — 촬영 중(장수 뱃지) · 인화 대기(남은 시간 뱃지) · 인화 완료(확인하기 버튼).
/// 홈 방 목록의 가로 스크롤에 쓰이며, 크기는 시안 고정(200×266) — 기기 폭과 무관한 물건 크기다.
///
/// 사진과 커버 스티커는 이미 로드된 `Image`를 받는다 — URL 로딩은 호출부 책임이라 이 컴포넌트는 네트워크의 존재를 모른다.
/// 인화 대기의 남은 시간도 표시 문자열로 받는다 — 시간 계산과 1초 갱신은 호출부(Feature)의 몫이고 카드는 그림이다.
/// 카드 자체의 탭은 받지 않는다 — 카드는 그림이고, 탭은 호출부가 Button 등으로 감싸서 처리한다.
/// 하단 뱃지·버튼만 예외로 자기 액션을 갖는다 (카드 탭과 다른 곳으로 가기 때문).
///
/// ```swift
/// CHALLARoomCard(title: "친구들과 강릉 여행", memberCount: 1, photo: photo,
///                variant: .shooting(shotCount: 24, totalCount: 24, isPreparing: false, onShoot: { store.send(.shootTapped) }))
/// CHALLARoomCard(title: "친구들과 유럽 여행", memberCount: 5, photo: photo, coverSticker: sticker,
///                variant: .printWaiting(remainingTime: "2:15:32"))
/// CHALLARoomCard(title: "친구들과 유럽 여행", memberCount: 5, photo: photo, coverSticker: sticker,
///                variant: .printed(onConfirm: { store.send(.confirmTapped) }))
/// ```
public struct CHALLARoomCard: View {

    // MARK: - 공개 타입

    /// 방 상태에 따라 달라지는 하단 요소. 공통 틀(사진·딤·제목·인원)은 상태와 무관하다.
    public enum Variant {
        /// 촬영 중 — 노랑 카메라 뱃지에 `찍은 장수/총 장수`를 보여준다.
        /// isPreparing이면 뱃지가 스피너로 바뀌고 눌리지 않는다.
        /// 준비가 카드마다 따로 도므로 어느 방을 눌렀는지도 이 값으로 드러난다.
        /// onShoot이 nil이면 뱃지는 장수만 보여주는 그림으로 남는다
        /// (촬영으로 갈 수 없는 자리에서 눌리는 것처럼 보이지 않게 한다).
        case shooting(shotCount: Int, totalCount: Int, isPreparing: Bool, onShoot: (() -> Void)?)
        /// 인화 대기 — 어두운 시계 뱃지에 남은 시간 문자열을 보여준다. 뱃지는 눌리지 않는 그림이다.
        case printWaiting(remainingTime: String)
        /// 인화 완료 — 노랑 확인하기 버튼. 테마색 글로우로 시선을 끈다.
        /// onConfirm이 nil이면 버튼 모양의 그림으로 남는다.
        case printed(onConfirm: (() -> Void)?)
    }

    // MARK: - 프로퍼티와 init

    private let title: String
    private let memberCount: Int
    private let photo: Image?
    private let coverSticker: Image?
    private let variant: Variant

    /// - Parameters:
    ///   - title: 방 이름. 길면 줄바꿈된다.
    ///   - memberCount: 참여 인원 수 (제목 아래 person 아이콘 옆).
    ///   - photo: 방 대표 사진 또는 커버 이미지. nil이면 바닥색만 보인다 (로딩 전·사진 없음 대응).
    ///   - coverSticker: 방 커버 스티커. 사진 위·딤 아래에 카드 전체 크기로 얹는다.
    ///     nil이면 커버를 설정하지 않은 방이다 (방 상태와 무관한 값).
    ///   - variant: 방 상태별 하단 요소.
    public init(
        title: String,
        memberCount: Int,
        photo: Image?,
        coverSticker: Image? = nil,
        variant: Variant
    ) {
        self.title = title
        self.memberCount = memberCount
        self.photo = photo
        self.coverSticker = coverSticker
        self.variant = variant
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            background
            content
        }
        .frame(width: RoomCardMetric.width, height: RoomCardMetric.height)
        .clipShape(RoundedRectangle(cornerRadius: CHALLARadius.large))
        // 테두리는 clip 뒤에 얹어야 잘리지 않고 모서리를 따라 온전히 그려진다.
        .overlay {
            RoundedRectangle(cornerRadius: CHALLARadius.large)
                .strokeBorder(CHALLAColor.Line.normal, lineWidth: RoomCardMetric.borderWidth)
        }
        // 뱃지가 버튼일 때는 그 버튼이 따로 읽혀야 해서 카드를 하나로 합치지 않는다.
        .accessibilityElement(children: hasAction ? .contain : .ignore)
        .accessibilityLabel(hasAction ? Text("") : Text(cardAccessibilityLabel))
    }

    // MARK: - 배경

    /// 사진 채움은 FilmCard와 같은 방식 — Color가 크기를 잡고 사진은 overlay로 얹어 넘친 만큼 잘라낸다.
    /// 층 순서는 시안 그대로: 사진 → 커버 스티커 → 딤.
    private var background: some View {
        CHALLAColor.Background.level2
            .overlay {
                if let photo {
                    photo
                        .resizable()
                        .scaledToFill()
                }
            }
            .overlay {
                if let coverSticker {
                    coverSticker
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .overlay { scrim }
    }

    /// 위에서 아래로 깔리는 딤 2겹 — 검정(0.8→0.2, 상단 텍스트 가독성) + 흰색 하이라이트(0.2→0).
    private var scrim: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: CHALLAColor.Static.black.opacity(RoomCardMetric.scrimTopOpacity), location: 0),
                    .init(color: CHALLAColor.Static.black.opacity(RoomCardMetric.scrimBottomOpacity), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                stops: [
                    .init(color: CHALLAColor.Static.white.opacity(RoomCardMetric.highlightOpacity), location: 0),
                    .init(color: .clear, location: RoomCardMetric.highlightEnd)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - 콘텐츠

    /// 위(제목·인원)와 아래(상태별 요소)를 Spacer로 밀어낸다.
    /// Figma의 gap 146은 카드 높이에서 나온 파생값이라 하드코딩하지 않는다.
    private var content: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: RoomCardMetric.titleMemberGap) {
                Text(title)
                    .challaFont(.body.medium.bold)
                    .foregroundStyle(CHALLAColor.Label.normal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                memberRow
            }
            Spacer(minLength: 0)
            bottomElement
        }
        .padding(RoomCardMetric.contentPadding)
    }

    private var memberRow: some View {
        HStack(spacing: RoomCardMetric.memberIconGap) {
            CHALLAIcon.person.image(size: .size14, color: CHALLAColor.Label.subtle)
            Text("\(memberCount)")
                .challaFont(.description.large.bold)
                .foregroundStyle(CHALLAColor.Label.subtle)
        }
    }

    private var hasAction: Bool {
        switch variant {
        case .shooting(_, _, _, let onShoot): onShoot != nil
        case .printWaiting: false
        case .printed(let onConfirm): onConfirm != nil
        }
    }

    private var cardAccessibilityLabel: String {
        switch variant {
        case .shooting(let shot, let total, _, _):
            "\(title), \(memberCount)명 참여, 사진 \(shot)/\(total)장 촬영 중"
        case .printWaiting(let remaining):
            "\(title), \(memberCount)명 참여, 인화까지 \(remaining) 남음"
        case .printed:
            "\(title), \(memberCount)명 참여, 인화 완료"
        }
    }

    // MARK: - 상태별 하단 요소

    @ViewBuilder
    private var bottomElement: some View {
        switch variant {
        case .shooting(let shot, let total, let isPreparing, let onShoot):
            shootingBadge(shot: shot, total: total, isPreparing: isPreparing, onShoot: onShoot)
        case .printWaiting(let remaining):
            waitingBadge(remaining: remaining)
        case .printed(let onConfirm):
            confirmButton(onConfirm: onConfirm)
        }
    }

    @ViewBuilder
    private func shootingBadge(shot: Int, total: Int, isPreparing: Bool, onShoot: (() -> Void)?) -> some View {
        if let onShoot {
            Button(action: onShoot) {
                shootingBadgeSurface(shot: shot, total: total, isPreparing: isPreparing)
            }
            .buttonStyle(.plain)
            .disabled(isPreparing)
            .accessibilityLabel("촬영하기")
            .accessibilityHint("\(title), 사진 \(shot)/\(total)장 촬영 중")
        } else {
            shootingBadgeSurface(shot: shot, total: total, isPreparing: isPreparing)
        }
    }

    private func shootingBadgeSurface(shot: Int, total: Int, isPreparing: Bool) -> some View {
        // 스피너와 원래 내용의 폭이 달라 뱃지가 들썩이지 않도록 겹쳐 두고 보이는 쪽만 바꾼다.
        ZStack {
            HStack(spacing: RoomCardMetric.badgeContentGap) {
                CHALLAIcon.camera.image(size: .size22, color: CHALLAColor.Static.black)
                Text("\(shot)/\(total)")
                    .challaFont(.body.medium.bold)
                    .foregroundStyle(CHALLAColor.Static.black)
            }
            .opacity(isPreparing ? 0 : 1)
            if isPreparing {
                ProgressView()
                    .tint(CHALLAColor.Static.black)
            }
        }
        .padding(.horizontal, RoomCardMetric.badgeHorizontalPadding)
        .padding(.vertical, RoomCardMetric.badgeVerticalPadding)
        .background {
            RoundedRectangle(cornerRadius: CHALLARadius.large)
                .fill(CHALLAColor.Primary.yellow)
        }
    }

    private func waitingBadge(remaining: String) -> some View {
        HStack(spacing: RoomCardMetric.badgeContentGap) {
            CHALLAIcon.clock.image(size: .size22, color: CHALLAColor.Label.neutral)
            Text(remaining)
                .challaFont(.body.medium.bold)
                .foregroundStyle(CHALLAColor.Label.neutral)
                // 초가 줄어들 때마다 숫자 폭이 달라져 뱃지가 들썩이는 것을 막는다.
                .monospacedDigit()
        }
        .padding(.horizontal, RoomCardMetric.badgeHorizontalPadding)
        .padding(.vertical, RoomCardMetric.badgeVerticalPadding)
        .background {
            RoundedRectangle(cornerRadius: CHALLARadius.large)
                .fill(CHALLAColor.Background.level4)
        }
    }

    @ViewBuilder
    private func confirmButton(onConfirm: (() -> Void)?) -> some View {
        if let onConfirm {
            Button(action: onConfirm) {
                confirmButtonSurface
            }
            .buttonStyle(.plain)
            .accessibilityLabel("확인하기")
            .accessibilityHint("\(title) 인화 완료")
        } else {
            confirmButtonSurface
        }
    }

    private var confirmButtonSurface: some View {
        HStack(spacing: RoomCardMetric.badgeContentGap) {
            CHALLAIcon.cameraRoll.image(size: .size22, color: CHALLAColor.Static.black)
            Text("확인하기")
                .challaFont(.body.medium.bold)
                .foregroundStyle(CHALLAColor.Static.black)
        }
        .padding(.horizontal, RoomCardMetric.badgeHorizontalPadding)
        .padding(.vertical, RoomCardMetric.badgeVerticalPadding)
        .background {
            RoundedRectangle(cornerRadius: CHALLARadius.large)
                .fill(CHALLAColor.Primary.yellow)
        }
        .shadow(color: CHALLAColor.Primary.yellow, radius: RoomCardMetric.glowRadius)
    }
}

// MARK: - Figma 실측값

private enum RoomCardMetric {
    /// 카드 크기 — 시안 고정. 기기 대응은 목록(부모)이 여백·스크롤로 담당한다.
    static let width: CGFloat = 200
    static let height: CGFloat = 266
    /// 콘텐츠 전방향 패딩.
    static let contentPadding: CGFloat = 20
    /// 제목과 인원 행 사이 간격.
    static let titleMemberGap: CGFloat = 8
    /// person 아이콘과 인원 숫자 사이 간격.
    static let memberIconGap: CGFloat = 2
    /// 뱃지 내부 패딩과 아이콘-숫자 간격 — 세 상태가 같은 값을 쓴다.
    static let badgeHorizontalPadding: CGFloat = 11
    static let badgeVerticalPadding: CGFloat = 8
    static let badgeContentGap: CGFloat = 4
    /// 카드 테두리 두께 (색은 Line.normal — Figma rgba(129,129,129,0.22)와 동일 토큰).
    static let borderWidth: CGFloat = 2
    /// 검정 딤 시작·끝 불투명도 (Figma 0.8 → 0.2).
    static let scrimTopOpacity: Double = 0.8
    static let scrimBottomOpacity: Double = 0.2
    /// 흰색 하이라이트 시작 불투명도(0.2)와 소멸 지점(Figma 76.378%).
    static let highlightOpacity: Double = 0.2
    static let highlightEnd: CGFloat = 0.764
    /// 확인하기 버튼 글로우. Figma drop shadow(0 0 8)의 blur를 radius로 옮긴 시안 육안 근사값 — 디자이너 검수로 확정한다.
    static let glowRadius: CGFloat = 8
}

#Preview {
    let sampleURL = URL(string: "https://picsum.photos/seed/challa-room/400/532")

    // 카드 두 장을 가로로 놓으면 420pt로 화면 폭을 넘어 잘리므로 세로로 나열한다.
    ScrollView {
        VStack(spacing: 20) {
            AsyncImage(url: sampleURL) { photo in
                CHALLARoomCard(
                    title: "친구들과 강릉 여행",
                    memberCount: 11,
                    photo: photo,
                    variant: .shooting(shotCount: 24, totalCount: 24, isPreparing: false, onShoot: nil)
                )
            } placeholder: {
                ProgressView()
            }
            CHALLARoomCard(
                title: "촬영 준비 중",
                memberCount: 4,
                photo: nil,
                variant: .shooting(shotCount: 12, totalCount: 24, isPreparing: true, onShoot: {})
            )
            CHALLARoomCard(
                title: "인화 대기",
                memberCount: 5,
                photo: nil,
                variant: .printWaiting(remainingTime: "2:15:32")
            )
            CHALLARoomCard(
                title: "인화 완료",
                memberCount: 5,
                photo: nil,
                variant: .printed(onConfirm: {})
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
    .background(CHALLAColor.Background.surface)
}
