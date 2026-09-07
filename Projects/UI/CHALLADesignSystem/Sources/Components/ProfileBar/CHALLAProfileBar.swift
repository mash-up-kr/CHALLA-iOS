import SwiftUI

/// 디자인 시스템 프로필 바.
/// 참여자 아바타를 입장 순으로 최대 9명 겹쳐 보여주고, 초과분은 "+N" 칩으로 줄인다.
/// 바를 탭하면 아래로 멤버 팝오버(초대 코드 + 전체 리스트)가 열리며 바가 흰색에서 검정이 된다.
/// 닫기는 바 재탭 또는 팝오버 바깥 탭.
///
/// 열림 상태는 호출부가 소유한다(`isPresented`) — 드로어와 같은 방식이라 TCA Store로도 다룰 수 있다.
/// 팝오버(폭 200)는 바 중앙 아래에 뜬다 — 바를 화면 가로 중앙에 둘 것(가장자리면 잘림).
/// `popoverTooltip`을 주면 팝오버 아래에 안내 말풍선이 붙는다 — 언제 띄울지는 호출부가 정한다
/// (온보딩 기록 등은 이 컴포넌트가 모른다).
/// 열린 팝오버가 화면의 다른 뷰에 덮여 보이면, 이 컴포넌트에 `.zIndex(1)`을 붙여 위로 올린다
/// (SwiftUI는 나중에 선언된 뷰를 위에 그리기 때문 — ProfileBarGallery의 팝오버 섹션이 실제 예).
///
/// ```swift
/// CHALLAProfileBar(members: members, inviteCode: "1928121",
///                  isPresented: $isMemberListPresented,
///                  onCopyInviteCode: { /* 클립보드 복사는 호출부 책임 */ })
/// ```
public struct CHALLAProfileBar: View {

    // MARK: - 공개 타입

    /// 팝오버 리스트와 바 아바타에 쓰이는 참여자 한 명.
    /// 사진은 로드된 `Image` 또는 URL로 받는다 — URL이면 로드를 바가 `CHALLAAsyncImage`로 직접 한다.
    public struct Member: Identifiable {
        public let id: String
        public let name: String
        let avatarSource: AvatarSource

        enum AvatarSource {
            /// 호출부가 이미 로드해 둔 사진 — nil이면 placeholder.
            case image(Image?)
            /// 원격 사진 URL — 로딩 중·실패·nil이면 placeholder.
            case url(URL?)
        }

        /// - Parameters:
        ///   - id: 리스트 identity로 쓰는 서버 식별자.
        ///   - name: 닉네임.
        ///   - avatar: 프로필 사진. nil이면 placeholder.
        public init(id: String, name: String, avatar: Image?) {
            self.id = id
            self.name = name
            self.avatarSource = .image(avatar)
        }

        /// - Parameters:
        ///   - id: 리스트 identity로 쓰는 서버 식별자.
        ///   - name: 닉네임.
        ///   - avatarURL: 프로필 사진 URL. 바가 `CHALLAAsyncImage`로 로드하고, 로딩 중·실패·nil이면 placeholder.
        public init(id: String, name: String, avatarURL: URL?) {
            self.id = id
            self.name = name
            self.avatarSource = .url(avatarURL)
        }
    }

    // MARK: - 표기 규칙

    /// 바에 그리는 아바타 최대 수 (Figma: "방 입장 순으로 9명까지만 표기").
    nonisolated static let maxVisibleAvatars = 9

    /// 최대 표기 수를 넘을 때 "+N" 칩에 표시할 값. 넘지 않으면 nil (칩 없음).
    /// 방 정원과 무관하게 동작한다 — 정원 10명 vs 시안 "+4" 불일치는 디자이너 확인 예정.
    /// 순수 계산이라 MainActor 격리가 불필요하다 — View 타입의 static은 기본이
    /// MainActor라서, nonisolated가 없으면 테스트(메인 스레드 밖)에서 호출하지 못한다.
    nonisolated static func overflowCount(totalMemberCount: Int) -> Int? {
        guard totalMemberCount > maxVisibleAvatars else { return nil }
        return totalMemberCount - maxVisibleAvatars
    }

    // MARK: - 프로퍼티와 init

    @Environment(\.challaTheme) private var theme

    private let members: [Member]
    private let inviteCode: String
    @Binding private var isPresented: Bool
    private let popoverTooltip: String?
    private let onCopyInviteCode: () -> Void

    /// - Parameters:
    ///   - members: 방 입장 순 전체 참여자. 바에는 앞 9명만, 팝오버에는 전부 그린다.
    ///   - inviteCode: 팝오버 상단에 표시할 초대 코드.
    ///   - isPresented: 팝오버 열림 상태. 바 탭이 토글하고, 호출부도 언제든 바꿀 수 있다.
    ///   - popoverTooltip: 팝오버 아래에 붙일 안내 문구. nil이면 말풍선 없음 (기본).
    ///     팝오버가 열려 있을 때만 그려진다 — 닫힌 바 아래에 말풍선만 남지 않는다.
    ///   - onCopyInviteCode: 복사 버튼 탭 콜백.
    public init(
        members: [Member],
        inviteCode: String,
        isPresented: Binding<Bool>,
        popoverTooltip: String? = nil,
        onCopyInviteCode: @escaping () -> Void
    ) {
        self.members = members
        self.inviteCode = inviteCode
        self._isPresented = isPresented
        self.popoverTooltip = popoverTooltip
        self.onCopyInviteCode = onCopyInviteCode
    }

    // MARK: - Body

    public var body: some View {
        bar
            .onTapGesture { isPresented.toggle() }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("참여자 \(members.count)명")
            .accessibilityHint(isPresented ? "멤버 목록 닫기" : "멤버 목록 열기")
            .overlay {
                // 팝오버 바깥 탭 닫기용 투명 판 (디자이너 확정 스펙)
                if isPresented {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(
                            width: ProfileBarMetric.dismissCatcherSize,
                            height: ProfileBarMetric.dismissCatcherSize
                        )
                        .onTapGesture { isPresented = false }
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .top) {
                if isPresented {
                    VStack(spacing: ProfileBarMetric.tooltipGap) {
                        panel
                        if let popoverTooltip {
                            CHALLATooltip(popoverTooltip, position: .bottom, arrowAlignment: .center)
                        }
                    }
                    .offset(y: ProfileBarMetric.barHeight + ProfileBarMetric.panelGap)
                    // scale 전환은 anchor가 고정점이다 — .top이면 바에 붙은 윗변이 제자리에 있고
                    // 아래로만 펼쳐진다. 기본값 .center는 가운데가 고정이라 등장 중 윗변이 내려갔다 올라온다.
                    .transition(
                        .opacity.combined(with: .scale(scale: ProfileBarMetric.appearScale, anchor: .top))
                    )
                }
            }
            .animation(
                .spring(duration: ProfileBarMetric.toggleDuration, bounce: ProfileBarMetric.toggleBounce),
                value: isPresented
            )
    }

    // MARK: - 바 (아바타 스택)

    /// 겹침 배치를 HStack 음수 간격에 맡기지 않고 offset으로 직접 한다 —
    /// 음수 간격은 배경 캡슐이 내용보다 좁게 잡히는 문제가 있었다. 폭도 같은 이유로 직접 계산.
    private var bar: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(visibleMembers.enumerated()), id: \.element.id) { index, member in
                avatar(for: member, size: ProfileBarMetric.avatarSize)
                    .offset(x: CGFloat(index) * ProfileBarMetric.avatarStep)
                    // 먼저 입장한(왼쪽) 아바타가 겹침의 위로 오도록 (시안 스펙).
                    .zIndex(Double(visibleMembers.count - index))
            }
            if let overflow = Self.overflowCount(totalMemberCount: members.count) {
                overflowChip(overflow) // zIndex 기본 0 — 겹침의 제일 아래
                    .offset(x: CGFloat(visibleMembers.count) * ProfileBarMetric.avatarStep)
            }
        }
        .frame(width: barContentWidth, height: ProfileBarMetric.avatarSize, alignment: .leading)
        .padding(ProfileBarMetric.barPadding)
        // 바 배경색: 기본(닫힘) 흰색 → 팝오버 열림 검정 (디자이너 확정 스펙).
        // 색 전환은 body의 animation(value: isPresented)이 함께 처리한다.
        .background(
            Capsule().fill(isPresented ? CHALLAColor.Static.black : CHALLAColor.Static.white)
        )
    }

    /// 바에 그릴 앞 9명 (입장 순).
    private var visibleMembers: [Member] {
        Array(members.prefix(Self.maxVisibleAvatars))
    }

    /// 바 내용물 폭 = 첫 아바타 30 + 나머지 요소당 25(겹침 배치 간격).
    private var barContentWidth: CGFloat {
        let chipCount = Self.overflowCount(totalMemberCount: members.count) == nil ? 0 : 1
        let elementCount = visibleMembers.count + chipCount
        guard elementCount > 0 else { return 0 }
        return ProfileBarMetric.avatarSize + CGFloat(elementCount - 1) * ProfileBarMetric.avatarStep
    }

    /// 흰 배경(닫힘) 상태의 칩 색 시안이 없어 두 상태 같은 색을 쓴다 — 디자이너 확인 예정.
    private func overflowChip(_ count: Int) -> some View {
        Circle()
            .fill(CHALLAColor.Background.level1)
            .frame(width: ProfileBarMetric.avatarSize, height: ProfileBarMetric.avatarSize)
            .overlay {
                Text("+\(count)")
                    .challaFont(.description.large.bold)
                    .foregroundStyle(CHALLAColor.Label.neutral)
            }
            .overlay {
                Circle().strokeBorder(
                    CHALLAColor.Static.black,
                    lineWidth: ProfileBarMetric.chipBorderWidth
                )
            }
    }

    // MARK: - 멤버 팝오버

    private var panel: some View {
        VStack(spacing: ProfileBarMetric.panelSectionGap) {
            inviteCodeHeader
            CHALLAColor.Line.normal
                .frame(height: ProfileBarMetric.dividerHeight)
            memberList
        }
        .padding(ProfileBarMetric.panelPadding)
        .frame(width: ProfileBarMetric.panelWidth, height: panelHeight)
        .background {
            RoundedRectangle(cornerRadius: CHALLARadius.xlarge)
                .fill(CHALLAColor.Static.black)
        }
    }

    private var inviteCodeHeader: some View {
        VStack(spacing: ProfileBarMetric.codeLabelGap) {
            Text("초대 코드")
                .challaFont(.description.large.medium)
                .foregroundStyle(CHALLAColor.Label.neutral)
            HStack(spacing: ProfileBarMetric.codeCopyGap) {
                Text(inviteCode)
                    .challaFont(.heading.medium.bold)
                    .foregroundStyle(theme.accent)
                Button(action: onCopyInviteCode) {
                    CHALLAIcon.copy.image(size: .size20, color: CHALLAColor.Label.disabled)
                }
                .accessibilityLabel("초대 코드 복사")
            }
        }
    }

    private var memberList: some View {
        ScrollView {
            VStack(spacing: ProfileBarMetric.rowGap) {
                ForEach(members) { member in
                    memberRow(member)
                }
            }
        }
        // 내용이 팝오버 최대 높이 이내면 스크롤·바운스를 비활성화한다
        .scrollBounceBehavior(.basedOnSize)
    }

    private func memberRow(_ member: Member) -> some View {
        HStack(spacing: ProfileBarMetric.rowContentGap) {
            avatar(for: member, size: ProfileBarMetric.memberAvatarSize)
            Text(member.name)
                .challaFont(.body.xsmall.medium)
                .foregroundStyle(CHALLAColor.Label.subtle)
            Spacer(minLength: 0)
        }
        .frame(height: ProfileBarMetric.rowHeight)
    }

    // MARK: - 아바타

    /// 출처별 아바타 — URL이면 `CHALLAAsyncImage`가 로드하고, 로딩 중·실패 시 placeholder를 그린다.
    @ViewBuilder
    private func avatar(for member: Member, size: CGFloat) -> some View {
        switch member.avatarSource {
        case let .image(image):
            CHALLAAvatar(photo: image, size: size)
        case let .url(url):
            CHALLAAsyncImage(url: url) { image in
                CHALLAAvatar(photo: image, size: size)
            } placeholder: {
                CHALLAAvatar(photo: nil, size: size)
            }
        }
    }

    /// 팝오버 전체 높이 = 고정 요소 + 리스트 내용 높이, 상한 420 (Figma "max-height: 420px").
    /// overlay가 제안하는 크기는 바(40pt) 기준이라 믿을 수 없어, 행 높이가 고정(30)인 점을 이용해
    /// 직접 계산한다 — 인원이 적으면 내용만큼, 많으면 420에서 잘리고 리스트가 스크롤된다.
    private var panelHeight: CGFloat {
        let rowCount = CGFloat(members.count)
        let listHeight = rowCount * ProfileBarMetric.rowHeight
            + max(0, rowCount - 1) * ProfileBarMetric.rowGap
        let fixedHeight = ProfileBarMetric.headerHeight
            + ProfileBarMetric.dividerHeight
            + ProfileBarMetric.panelSectionGap * 2
            + ProfileBarMetric.panelPadding * 2
        return min(ProfileBarMetric.panelMaxHeight, fixedHeight + listHeight)
    }
}

// MARK: - Figma 실측값

private enum ProfileBarMetric {

    // MARK: 바

    static let avatarSize: CGFloat = 30
    /// 이웃과 5pt씩 겹치도록 지름보다 5 작게 전진.
    static let avatarStep: CGFloat = avatarSize - 5
    static let barPadding: CGFloat = 5
    static let barHeight: CGFloat = avatarSize + barPadding * 2
    /// 실측 3.67 — 시안 컴포넌트 스케일 흔적으로 보이는 소수값.
    static let chipBorderWidth: CGFloat = 3.67

    // MARK: 팝오버 틀

    static let panelGap: CGFloat = 8
    /// 2차 시안 실측 (7522:35546 · 6204:48497). 최대 높이는 프레임 max-height 420.
    static let panelWidth: CGFloat = 200
    static let panelMaxHeight: CGFloat = 420
    /// 팝오버 하단에서 툴팁까지.
    static let tooltipGap: CGFloat = 8
    static let panelPadding: CGFloat = 20
    static let panelSectionGap: CGFloat = 12
    static let dividerHeight: CGFloat = 1

    // MARK: 팝오버 내용

    static let codeLabelGap: CGFloat = 4
    static let codeCopyGap: CGFloat = 4
    /// 라벨 14 + 간격 4 + 코드 32.
    static let headerHeight: CGFloat = 50
    static let rowHeight: CGFloat = 30
    static let rowGap: CGFloat = 8
    static let rowContentGap: CGFloat = 8
    static let memberAvatarSize: CGFloat = 20

    // MARK: 동작

    /// 여닫이 스프링. 시안에 모션 명세 없음 — 셋 다 근사값, 디자이너 검수로 확정한다.
    /// duration은 대략의 정착 시간, bounce는 끝에서 넘었다 돌아오는 정도(0이면 튕김 없이 감속만).
    static let toggleDuration: Double = 0.3
    static let toggleBounce: Double = 0.2
    /// 등장 시작 크기 (0.92 → 1.0으로 커지며 나타난다). 1에 가까울수록 움직임이 은근하다.
    static let appearScale: CGFloat = 0.92
    /// 바깥 탭 닫기용 투명 판. iPhone 최대 화면 대각선(~1,026pt)보다 충분히 크다.
    static let dismissCatcherSize: CGFloat = 3000
}

#Preview {
    struct PreviewHost: View {
        @State private var isPresented = true

        var body: some View {
            VStack {
                CHALLAProfileBar(
                    members: (1 ... 13).map {
                        CHALLAProfileBar.Member(id: "\($0)", name: "멤버 \($0)", avatar: nil)
                    },
                    inviteCode: "1928121",
                    isPresented: $isPresented,
                    onCopyInviteCode: {}
                )
                Spacer()
            }
            .padding(.top, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CHALLAColor.Background.surface)
        }
    }
    return PreviewHost()
}
