import SwiftUI

/// 디자인 시스템 방 카드 (촬영 중).
/// 방 대표 사진 위에 딤 그라데이션을 깔고 제목·인원, 촬영 장수 뱃지를 겹쳐 보여준다.
/// 홈 방 목록의 "촬영 중" 방에 쓰이며, 크기는 시안 고정(200×266) — 기기 폭과 무관한 물건 크기다.
///
/// 사진은 이미 로드된 `Image`를 받는다 — URL 로딩은 호출부 책임이라 이 컴포넌트는 네트워크의 존재를 모른다.
/// 카드 자체의 탭은 받지 않는다 — 카드는 그림이고, 탭은 호출부가 Button 등으로 감싸서 처리한다.
/// 하단 촬영 뱃지만 예외로 자기 액션을 갖는다 (카드 탭과 다른 곳으로 가기 때문).
///
/// ```swift
/// CHALLACardItem(title: "친구들과 강릉 여행", memberCount: 11, photoCount: 24, photo: photo)
/// CHALLACardItem(title: "…", memberCount: 11, photoCount: 24, photo: photo, isPreparingShoot: isLoading) {
///     store.send(.shootTapped)
/// }
/// ```
public struct CHALLACardItem: View {

    // MARK: - 프로퍼티와 init

    private let title: String
    private let memberCount: Int
    private let photoCount: Int
    private let photo: Image?
    private let isPreparingShoot: Bool
    private let onShoot: (() -> Void)?

    /// - Parameters:
    ///   - title: 방 이름. 길면 줄바꿈된다.
    ///   - memberCount: 참여 인원 수 (제목 아래 person 아이콘 옆).
    ///   - photoCount: 지금까지 촬영된 장수 (하단 카메라 뱃지).
    ///   - photo: 방 대표 사진. nil이면 바닥색만 보인다 (로딩 전·사진 없음 대응).
    ///   - isPreparingShoot: 촬영 화면에 들어갈 준비 중이면 뱃지가 스피너로 바뀌고 눌리지 않는다.
    ///     준비가 카드마다 따로 도므로 어느 방을 눌렀는지도 이 값으로 드러난다.
    ///   - onShoot: 촬영 뱃지를 눌렀을 때. nil이면 뱃지는 장수만 보여주는 그림으로 남는다
    ///     (촬영으로 갈 수 없는 자리에서 눌리는 것처럼 보이지 않게 한다).
    public init(
        title: String,
        memberCount: Int,
        photoCount: Int,
        photo: Image?,
        isPreparingShoot: Bool = false,
        onShoot: (() -> Void)? = nil
    ) {
        self.title = title
        self.memberCount = memberCount
        self.photoCount = photoCount
        self.photo = photo
        self.isPreparingShoot = isPreparingShoot
        self.onShoot = onShoot
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            background
            content
        }
        .frame(width: CardItemMetric.width, height: CardItemMetric.height)
        .clipShape(RoundedRectangle(cornerRadius: CHALLARadius.large))
        // 뱃지가 버튼일 때는 그 버튼이 따로 읽혀야 해서 카드를 하나로 합치지 않는다.
        .accessibilityElement(children: onShoot == nil ? .ignore : .contain)
        .accessibilityLabel(onShoot == nil ? Text(cardAccessibilityLabel) : Text(""))
    }

    // MARK: - 배경

    /// 사진 채움은 FilmCard와 같은 방식 — Color가 크기를 잡고 사진은 overlay로 얹어 넘친 만큼 잘라낸다.
    private var background: some View {
        CHALLAColor.Background.level2
            .overlay {
                if let photo {
                    photo
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .overlay { scrim }
    }

    /// 위에서 아래로 깔리는 딤 2겹 — 검정(제목 가독성 확보) + 노랑 틴트(브랜드 톤).
    /// Figma에 유사한 그라데이션 레이어가 중첩돼 있어 합성 결과의 근사값으로 구현 — 디자이너 검수로 확정한다.
    private var scrim: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: CHALLAColor.Static.black.opacity(CardItemMetric.scrimOpacity), location: 0),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                stops: [
                    .init(color: CHALLAColor.Primary.yellow.opacity(CardItemMetric.tintOpacity), location: 0),
                    .init(color: CHALLAColor.Primary.yellow.opacity(0), location: CardItemMetric.tintEnd)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - 콘텐츠

    /// 위(제목·인원)와 아래(뱃지)를 Spacer로 밀어낸다.
    /// Figma의 gap 146은 카드 높이에서 나온 파생값이라 하드코딩하지 않는다.
    private var content: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: CardItemMetric.titleMemberGap) {
                Text(title)
                    .challaFont(.body.medium.bold)
                    .foregroundStyle(CHALLAColor.Label.normal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                memberRow
            }
            Spacer(minLength: 0)
            badge
        }
        .padding(CardItemMetric.contentPadding)
    }

    private var memberRow: some View {
        HStack(spacing: CardItemMetric.memberIconGap) {
            CHALLAIcon.person.image(size: .size14, color: CHALLAColor.Label.subtle)
            Text("\(memberCount)")
                .challaFont(.description.large.bold)
                .foregroundStyle(CHALLAColor.Label.subtle)
        }
    }

    private var cardAccessibilityLabel: String {
        "\(title), \(memberCount)명 참여, 사진 \(photoCount)장 촬영 중"
    }

    // MARK: - 촬영 뱃지

    @ViewBuilder
    private var badge: some View {
        if let onShoot {
            Button(action: onShoot) {
                badgeSurface
            }
            .buttonStyle(.plain)
            .disabled(isPreparingShoot)
            .accessibilityLabel("촬영하기")
            .accessibilityHint("\(title), 사진 \(photoCount)장 촬영 중")
        } else {
            badgeSurface
        }
    }

    private var badgeSurface: some View {
        // 스피너와 원래 내용의 폭이 달라 뱃지가 들썩이지 않도록 겹쳐 두고 보이는 쪽만 바꾼다.
        ZStack {
            badgeContent
                .opacity(isPreparingShoot ? 0 : 1)
            if isPreparingShoot {
                ProgressView()
                    .tint(CHALLAColor.Static.black)
            }
        }
        .padding(.horizontal, CardItemMetric.badgeHorizontalPadding)
        .padding(.vertical, CardItemMetric.badgeVerticalPadding)
        .background {
            RoundedRectangle(cornerRadius: CHALLARadius.large)
                .fill(CHALLAColor.Primary.yellow)
        }
    }

    private var badgeContent: some View {
        HStack(spacing: CardItemMetric.badgeContentGap) {
            CHALLAIcon.camera.image(size: .size22, color: CHALLAColor.Static.black)
            Text("\(photoCount)")
                .challaFont(.body.medium.bold)
                .foregroundStyle(CHALLAColor.Static.black)
        }
    }
}

// MARK: - Figma 실측값

private enum CardItemMetric {
    /// 카드 크기 — 시안 고정. 기기 대응은 목록(부모)이 여백·스크롤로 담당한다.
    static let width: CGFloat = 200
    static let height: CGFloat = 266
    /// 콘텐츠 전방향 패딩.
    static let contentPadding: CGFloat = 20
    /// 제목과 인원 행 사이 간격.
    static let titleMemberGap: CGFloat = 8
    /// person 아이콘과 인원 숫자 사이 간격.
    static let memberIconGap: CGFloat = 2
    /// 뱃지 내부 패딩과 아이콘-숫자 간격.
    static let badgeHorizontalPadding: CGFloat = 11
    static let badgeVerticalPadding: CGFloat = 8
    static let badgeContentGap: CGFloat = 4
    /// 검정 딤 시작 불투명도 (Figma 0.5).
    static let scrimOpacity: Double = 0.5
    /// 노랑 틴트 시작 불투명도(0.2)와 소멸 지점(38%) — 중첩 레이어 합성의 근사값.
    static let tintOpacity: Double = 0.2
    static let tintEnd: CGFloat = 0.38
}

#Preview {
    let sampleURL = URL(string: "https://picsum.photos/seed/challa-room/400/532")

    // 카드 두 장을 가로로 놓으면 420pt로 화면 폭을 넘어 잘리므로 세로로 나열한다.
    ScrollView {
        VStack(spacing: 20) {
            AsyncImage(url: sampleURL) { photo in
                CHALLACardItem(title: "친구들과 강릉 여행", memberCount: 11, photoCount: 24, photo: photo)
            } placeholder: {
                ProgressView()
            }
            CHALLACardItem(title: "사진 없는 방", memberCount: 1, photoCount: 0, photo: nil)
            CHALLACardItem(title: "촬영 버튼", memberCount: 4, photoCount: 12, photo: nil) {}
            CHALLACardItem(
                title: "촬영 준비 중",
                memberCount: 4,
                photoCount: 12,
                photo: nil,
                isPreparingShoot: true
            ) {}
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
    .background(CHALLAColor.Background.surface)
}
