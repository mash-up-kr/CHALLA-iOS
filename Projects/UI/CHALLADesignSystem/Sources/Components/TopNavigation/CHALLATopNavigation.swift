import SwiftUI

/// 디자인 시스템 탑 내비게이션 바.
/// variant 2가지: main(좌측 고정 홈 로고) / sub(중앙 타이틀), 좌우 아이콘 슬롯 옵션.
///
/// 아이콘 슬롯은 Figma 실측 규격(아이콘 24pt + 터치 영역 40pt)이
/// `CHALLAIconButton` medium(아이콘 20pt)과 달라 내비 전용으로 그린다
/// (드로어 닫기 버튼과 같은 규격 — Drawer 구현 시 재사용 후보).
///
/// 상태바 영역(safe area)은 포함하지 않는다 — 화면 최상단에 붙이면 SwiftUI가 알아서 비켜준다.
///
/// ```swift
/// CHALLATopNavigation.main(trailing: .icon(.setting, accessibilityLabel: "설정") { ... })
///
/// CHALLATopNavigation.sub(
///     title: "방 만들기",
///     leading: .icon(.caretLeft, accessibilityLabel: "뒤로 가기") { ... },
///     trailing: .icon(.close, accessibilityLabel: "닫기") { ... }
/// )
/// ```
public struct CHALLATopNavigation: View {

    /// 좌우 슬롯에 들어가는 액션.
    public struct Item {
        let icon: CHALLAIcon
        let accessibilityLabel: String
        let action: () -> Void

        private init(icon: CHALLAIcon, accessibilityLabel: String, action: @escaping () -> Void) {
            self.icon = icon
            self.accessibilityLabel = accessibilityLabel
            self.action = action
        }

        /// 아이콘 액션 (24pt로 그려진다).
        /// - Parameters:
        ///   - icon: 표시할 아이콘.
        ///   - accessibilityLabel: VoiceOver가 읽을 한국어 설명 (아이콘 버튼과 동일하게 필수).
        public static func icon(
            _ icon: CHALLAIcon,
            accessibilityLabel: String,
            action: @escaping () -> Void
        ) -> Item {
            Item(icon: icon, accessibilityLabel: accessibilityLabel, action: action)
        }
    }

    private enum Variant {
        case main(trailing: Item?)
        case sub(title: String, leading: Item?, trailing: Item?)
    }

    private let variant: Variant

    private init(variant: Variant) {
        self.variant = variant
    }

    /// 홈 화면용. 좌측에 "home" 로고(Dirtyline)가 고정으로 들어간다.
    public static func main(trailing: Item? = nil) -> Self {
        Self(variant: .main(trailing: trailing))
    }

    /// 서브 화면용. 타이틀이 중앙 고정이고 좌우 슬롯은 옵션.
    public static func sub(
        title: String,
        leading: Item? = nil,
        trailing: Item? = nil
    ) -> Self {
        Self(variant: .sub(title: title, leading: leading, trailing: trailing))
    }

    public var body: some View {
        Group {
            switch variant {
            case .main(let trailing):
                mainBar(trailing: trailing)
            case .sub(let title, let leading, let trailing):
                subBar(title: title, leading: leading, trailing: trailing)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Metric.barHeight)
    }

    /// main: 로고 왼쪽 정렬 + 우측 아이콘.
    private func mainBar(trailing: Item?) -> some View {
        HStack(spacing: Metric.contentSpacing) {
            // Dirtyline은 소문자를 스타일된 대문자꼴로 그린다 — Figma 원문도 "home"
            Text("home")
                .challaFont(.heading.home)
                .foregroundStyle(CHALLAColor.Primary.yellow)
            Spacer(minLength: 0)
            if let trailing {
                iconSlot(trailing)
            }
        }
        .padding(.horizontal, Metric.horizontalPadding)
    }

    /// sub: 타이틀은 좌우 슬롯 유무와 무관하게 항상 화면 중앙 (Figma도 절대 위치 중앙).
    private func subBar(title: String, leading: Item?, trailing: Item?) -> some View {
        ZStack {
            Text(title)
                .challaFont(.body.large.bold)
                .foregroundStyle(CHALLAColor.Label.normal)
                .lineLimit(1)
                // 타이틀이 길어도 좌우 슬롯(40pt)과 겹치지 않게 가용 폭을 제한
                .padding(.horizontal, Metric.horizontalPadding + Metric.touchArea)
            HStack {
                if let leading {
                    iconSlot(leading)
                }
                Spacer(minLength: 0)
                if let trailing {
                    iconSlot(trailing)
                }
            }
            .padding(.horizontal, Metric.horizontalPadding)
        }
    }

    /// 아이콘 24pt를 40pt 터치 영역 가운데에 두고, 영역 전체가 탭에 반응한다.
    private func iconSlot(_ item: Item) -> some View {
        Button(action: item.action) {
            item.icon.image(size: .size24)
                .frame(width: Metric.touchArea, height: Metric.touchArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.accessibilityLabel)
    }
}

// MARK: - Figma 실측값

private enum Metric {
    /// 바 높이 (상태바 제외).
    static let barHeight: CGFloat = 70
    /// 좌우 가장자리 패딩.
    static let horizontalPadding: CGFloat = 16
    /// main variant의 로고·아이콘 사이 간격.
    static let contentSpacing: CGFloat = 16
    /// 아이콘 터치 영역 (아이콘 24pt를 가운데 배치).
    static let touchArea: CGFloat = 40
}

#Preview {
    VStack(spacing: 0) {
        CHALLATopNavigation.main()
        CHALLATopNavigation.main(trailing: .icon(.setting, accessibilityLabel: "설정") {})
        CHALLATopNavigation.sub(title: "타이틀")
        CHALLATopNavigation.sub(
            title: "방 만들기",
            leading: .icon(.caretLeft, accessibilityLabel: "뒤로 가기") {},
            trailing: .icon(.close, accessibilityLabel: "닫기") {}
        )
    }
    .background(CHALLAColor.Background.surface)
}
