import SwiftUI

/// 디자인 시스템 리스트 행.
///
/// 설정 화면과 그 하위 화면(테마 선택·알림)이 모두 이 행으로 조립된다.
/// 설명을 넣으면 행이 2줄 높이(52 → 74)로 커진다.
/// 보통 `CHALLAListSection` 안에 넣어 카드로 묶는다.
///
/// 이니셜라이저가 두 가지다 — **탭 행**과 **토글 행**은 동작도 접근성 의미도 다르기 때문이다.
///
/// ```swift
/// // 탭 행
/// CHALLAListRow("테마", icon: .palette, accessory: .arrow(value: "레몬에이드")) { ... }
/// CHALLAListRow("알림", icon: .bellSimple) { ... }
/// CHALLAListRow("레몬에이드", icon: .circle, iconColor: CHALLAColor.Primary.yellow,
///               accessory: .check(isSelected: true)) { ... }
///
/// // 토글 행 — 행 전체가 스위치라 action이 없다
/// CHALLAListRow("서비스 알림", description: "인화 대기, 인화 완료 등", isOn: $isOn)
/// ```
public struct CHALLAListRow: View {

    /// 행이 어떤 물건인지. 탭 행과 토글 행은 탭 처리·접근성 트레잇이 완전히 다르다.
    private enum Kind {
        case tappable(accessory: CHALLAListRowAccessory, action: (() -> Void)?)
        case toggle(isOn: Binding<Bool>)
    }

    private let title: String
    private let description: String?
    private let icon: CHALLAIcon?
    private let iconColor: Color
    private let themeColor: Color
    private let kind: Kind

    /// 탭 행.
    /// - Parameters:
    ///   - title: 행의 이름.
    ///   - description: 이름 아래 보조 설명. 넣으면 행 높이가 52 → 74로 커진다.
    ///   - icon: 왼쪽 아이콘. 시안의 모든 행에는 아이콘이 있지만, 없는 화면을 위해 옵션으로 둔다.
    ///   - iconColor: 아이콘 색. 테마 선택 화면처럼 팔레트 색을 입혀야 할 때 바꾼다.
    ///   - accessory: 우측 요소. 기본은 화면 이동을 뜻하는 화살표 —
    ///     `action`을 생략해 눌리지 않는 행을 만들 때는 `.empty`를 함께 넘긴다
    ///     (화살표만 남으면 누를 수 있는 것처럼 보인다).
    ///   - themeColor: 사용자가 고른 테마 색. `.arrow(value:)`의 값 글자에 쓰인다.
    ///   - action: 행 전체를 눌렀을 때 실행할 동작. 생략하면 눌리지 않는 행이 된다.
    public init(
        _ title: String,
        description: String? = nil,
        icon: CHALLAIcon? = nil,
        iconColor: Color = CHALLAColor.Label.neutral,
        accessory: CHALLAListRowAccessory = .arrow,
        themeColor: Color = CHALLAColor.defaultTheme,
        action: (() -> Void)? = nil
    ) {
        if case .arrow = accessory, action == nil {
            assertionFailure("눌리지 않는 행에 화살표를 두면 누를 수 있는 것처럼 보인다 — accessory: .empty 를 함께 넘길 것")
        }
        self.title = title
        self.description = description
        self.icon = icon
        self.iconColor = iconColor
        self.themeColor = themeColor
        kind = .tappable(accessory: accessory, action: action)
    }

    /// 토글 행. 행 전체가 스위치이므로 `action`을 받지 않는다.
    /// - Parameters:
    ///   - isOn: 스위치 상태. 소유는 호출부가 한다.
    ///   - themeColor: 사용자가 고른 테마 색. 스위치가 켜졌을 때의 배경에 쓰인다.
    public init(
        _ title: String,
        description: String? = nil,
        icon: CHALLAIcon? = nil,
        iconColor: Color = CHALLAColor.Label.neutral,
        themeColor: Color = CHALLAColor.defaultTheme,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.iconColor = iconColor
        self.themeColor = themeColor
        kind = .toggle(isOn: isOn)
    }

    public var body: some View {
        switch kind {
        case let .toggle(isOn):
            toggleContent(isOn: isOn)

        case let .tappable(accessory, action):
            if let action {
                Button(action: action) { content(accessory) }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectionTraits(of: accessory))
            } else {
                content(accessory)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(selectionTraits(of: accessory))
            }
        }
    }

    /// 토글 행. **스위치를 눌러야 켜고 꺼진다** — 이름을 눌러도 바뀌지 않는다.
    /// iOS 설정 앱과 같은 규칙이고, 시안에는 인터랙션 명세가 없어 플랫폼 관행을 따른다.
    /// 스위치 높이(26)가 최소 터치 타깃(44)보다 작아 히트 영역만 보이지 않게 넓힌다.
    ///
    /// 스위치를 직접 그리면서 접근성만 표준 `Toggle`로 내보낸다 —
    /// 트레잇·"켜짐/꺼짐" 낭독·더블탭 동작을 SwiftUI가 만들어 주므로 손으로 붙일 필요가 없다.
    /// (`Toggle` + 커스텀 `ToggleStyle`로 감싸면 바깥 `Toggle`이 얹는 시맨틱과 겹쳐
    /// 값이 두 번 읽히거나 더블탭이 두 번 토글되는 경로가 생긴다.)
    /// VoiceOver에서는 행 전체가 스위치 하나로 읽힌다 — 이것도 설정 앱과 같다.
    private func toggleContent(isOn: Binding<Bool>) -> some View {
        HStack(spacing: 0) {
            label
                .layoutPriority(1)
            Spacer(minLength: ListRowMetric.labelAccessoryMinGap)
            ListSwitch(isOn: isOn.wrappedValue, themeColor: themeColor)
                .padding(.trailing, ListRowMetric.switchTrailingInset)
                .contentShape(Rectangle().expandedToHitTarget(from: ListRowMetric.switchHeight))
                .onTapGesture { isOn.wrappedValue.toggle() }
        }
        .frame(height: rowHeight)
        .accessibilityRepresentation {
            Toggle(isOn: isOn) { Text(accessibilityLabel) }
        }
    }

    /// VoiceOver가 읽을 이름. 설명이 있으면 함께 묶어 한 번에 읽는다.
    private var accessibilityLabel: String {
        guard let description else { return title }
        return "\(title), \(description)"
    }

    private func content(_ accessory: CHALLAListRowAccessory) -> some View {
        HStack(spacing: 0) {
            label
                // 제목이 먼저 자리를 잡고, 자리가 모자라면 우측 값이 말줄임된다.
                // 우선순위는 같은 스택 안에서만 겨루므로 반드시 이 위치여야 한다 —
                // 안쪽 Text에 걸면 형제(화살표)하고만 겨뤄서 제목·값 경쟁에는 영향이 없다.
                .layoutPriority(1)
            Spacer(minLength: ListRowMetric.labelAccessoryMinGap)
            accessoryView(accessory)
        }
        .frame(height: rowHeight)
        // 시안에 행 사이 구분선이 없어 경계가 보이지 않으므로,
        // 글자 밖 빈 곳을 눌러도 반응하도록 행 전체를 탭 영역으로 만든다.
        // 행 높이(52·74)가 이미 HIG 최소 터치 타깃(44)보다 커서 별도 확장은 필요 없다.
        .contentShape(Rectangle())
    }

    /// 왼쪽 묶음 — 아이콘 + (이름 / 설명).
    /// 행 높이가 고정이라 줄바꿈되면 위아래 행과 겹치므로 둘 다 한 줄로 잠근다 (버튼과 같은 정책).
    private var label: some View {
        HStack(spacing: 0) {
            if let icon {
                icon.image(size: ListRowMetric.iconSize, color: iconColor)
                    .padding(.trailing, ListRowMetric.iconTitleSpacing)
            }
            VStack(alignment: .leading, spacing: ListRowMetric.titleDescriptionSpacing) {
                Text(title)
                    .challaFont(ListRowMetric.titleTypography)
                    .foregroundStyle(CHALLAColor.Label.subtle)
                    .lineLimit(1)
                if let description {
                    Text(description)
                        .challaFont(ListRowMetric.descriptionTypography)
                        .foregroundStyle(CHALLAColor.Label.alternative)
                        .lineLimit(1)
                }
            }
        }
    }

    /// 오른쪽 묶음 — accessory 종류별 표현.
    /// 시안의 32×32 상자는 배경이 없어 위치만 잡는 용도라, 여기서도 크기만 맞춘다.
    @ViewBuilder
    private func accessoryView(_ accessory: CHALLAListRowAccessory) -> some View {
        switch accessory {
        case let .arrow(value):
            HStack(spacing: ListRowMetric.valueArrowSpacing) {
                if let value {
                    Text(value)
                        .challaFont(ListRowMetric.titleTypography)
                        .foregroundStyle(themeColor)
                        .lineLimit(1)
                }
                // 시안에서 이 자리는 `iconButton / Transparent / Small`(32×32) 인스턴스지만
                // 아이콘으로만 그린다 — 행 전체가 이미 버튼이라 안에 버튼을 또 넣으면
                // VoiceOver가 두 번 멈춘다. Transparent는 배경이 없어 보이는 결과는 같다.
                CHALLAIcon.caretRight
                    .image(size: ListRowMetric.arrowIconSize, color: CHALLAColor.Label.alternative)
                    .frame(width: ListRowMetric.accessoryBox, height: ListRowMetric.accessoryBox)
            }

        case let .check(isSelected):
            // 선택 여부가 색으로만 구분되므로, VoiceOver에는 트레잇(selectionTraits)으로 따로 알린다.
            CHALLAIcon.check
                .image(
                    size: ListRowMetric.checkIconSize,
                    color: isSelected ? CHALLAColor.Static.white : CHALLAColor.Label.disabled
                )
                .frame(width: ListRowMetric.accessoryBox, height: ListRowMetric.accessoryBox)

        case .empty:
            EmptyView()
        }
    }

    /// 체크 행의 선택 상태를 VoiceOver에 알린다 (색 차이만으로는 전달되지 않는다).
    private func selectionTraits(of accessory: CHALLAListRowAccessory) -> AccessibilityTraits {
        if case let .check(isSelected) = accessory, isSelected {
            return .isSelected
        }
        return []
    }

    private var rowHeight: CGFloat {
        description == nil ? ListRowMetric.rowHeight : ListRowMetric.rowHeightWithDescription
    }
}

// MARK: - Toggle

/// 시안 규격(47×26)의 스위치. iOS 기본 스위치(51×31)와 크기가 달라 직접 그린다.
/// 켜짐 배경은 사용자가 고른 테마 색을 따른다 (꺼짐은 테마와 무관하게 `Label.disabled` 고정).
private struct ListSwitch: View {

    let isOn: Bool
    let themeColor: Color

    var body: some View {
        Capsule()
            .fill(isOn ? themeColor : CHALLAColor.Label.disabled)
            .frame(width: ListRowMetric.switchWidth, height: ListRowMetric.switchHeight)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(CHALLAColor.Static.white)
                    .frame(width: ListRowMetric.switchKnob, height: ListRowMetric.switchKnob)
                    .padding(ListRowMetric.switchKnobInset)
            }
            // 탭뿐 아니라 바깥(리듀서 등)에서 바뀔 때도 같은 속도로 움직이게 한다.
            .animation(.easeInOut(duration: ListRowMetric.switchAnimationDuration), value: isOn)
    }
}

// MARK: - Zeplin 실측값

private enum ListRowMetric {

    /// 기본 행 높이.
    static let rowHeight: CGFloat = 52
    /// 설명이 붙은 행의 높이.
    static let rowHeightWithDescription: CGFloat = 74

    static let titleTypography = CHALLATypography.body.medium.medium
    static let descriptionTypography = CHALLATypography.body.xsmall.medium

    static let iconSize = CHALLAIcon.Size.size18
    /// 아이콘과 이름 사이 간격.
    static let iconTitleSpacing: CGFloat = 10

    /// 이름과 설명 사이 간격.
    /// 시안 간격은 6이지만 `challaFont`가 두 글자 상자에 각각 위아래 여백을 더하므로
    /// 그만큼 빼야 화면에서 6으로 보인다.
    static let titleDescriptionSpacing: CGFloat = max(
        0,
        6 - ListRowMetric.titleTypography.lineBoxInset - ListRowMetric.descriptionTypography.lineBoxInset
    )

    /// 이름 묶음과 우측 요소가 최소한 벌어져야 하는 거리 (이름이 길 때 붙지 않도록).
    static let labelAccessoryMinGap: CGFloat = 8

    /// 우측 요소가 차지하는 정사각 상자 (배경 없이 위치만 잡는다).
    static let accessoryBox: CGFloat = 32
    static let arrowIconSize = CHALLAIcon.Size.size16
    static let checkIconSize = CHALLAIcon.Size.size22
    /// 값 텍스트와 화살표 사이 간격.
    static let valueArrowSpacing: CGFloat = 2

    /// 스위치를 카드 오른쪽 끝에서 추가로 떨어뜨리는 거리.
    ///
    /// 시안의 카드 오른쪽 안여백이 행 종류에 따라 다르다 — 화살표 행 16, 토글 행 20.
    /// 화살표 행은 우측 32 상자 안에 16 아이콘이 가운데 놓여 상자가 4만큼 더 파고들기 때문이다
    /// (눈에 보이는 여백은 16 + 8 = 24).
    /// 카드(`CHALLAListSection`)는 16으로 통일하고, 상자가 없는 토글 행만 여기서 4를 더해 20을 맞춘다.
    static let switchTrailingInset: CGFloat = 4

    static let switchWidth: CGFloat = 47
    static let switchHeight: CGFloat = 26
    static let switchKnob: CGFloat = 20
    static let switchKnobInset: CGFloat = 3
    static let switchAnimationDuration: TimeInterval = 0.2
}

#Preview {
    @Previewable @State var isOn = false

    VStack(spacing: 0) {
        CHALLAListRow("테마", icon: .palette, accessory: .arrow(value: "레몬에이드")) {}
        CHALLAListRow("알림", icon: .bellSimple) {}
        CHALLAListRow("레몬에이드", icon: .circle, iconColor: CHALLAColor.Primary.yellow,
                      accessory: .check(isSelected: true)) {}
        CHALLAListRow("라즈베리", icon: .circle, iconColor: CHALLAColor.Primary.pink,
                      accessory: .check(isSelected: false)) {}
        CHALLAListRow("서비스 알림", description: "인화 대기, 인화 완료 등", isOn: $isOn)
    }
    .padding(.horizontal, 24)
    .background(CHALLAColor.Background.level1)
    .padding()
    .background(CHALLAColor.Background.surface)
}
