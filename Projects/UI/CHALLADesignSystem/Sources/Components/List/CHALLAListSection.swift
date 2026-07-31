import SwiftUI

/// 리스트 행들을 묶는 섹션 카드.
///
/// 설정 화면은 이 카드 여러 장을 세로로 쌓아 만든다.
/// 행 사이에는 구분선이 없고 간격도 0이다 — 카드 자체가 묶음의 경계 역할을 한다.
///
/// ```swift
/// CHALLAListSection("앱 설정") {
///     CHALLAListRow("테마", icon: .palette, accessory: .arrow(value: "레몬에이드")) { ... }
///     CHALLAListRow("알림", icon: .bellSimple) { ... }
/// }
/// ```
///
/// 헤더는 옵션이다 — 테마 선택 화면처럼 제목 없이 행만 담는 카드도 있다.
public struct CHALLAListSection<Content: View>: View {

    private let title: String?
    private let content: Content

    /// - Parameters:
    ///   - title: 카드 상단 제목. 생략하면 헤더 없이 행만 담는다.
    ///   - content: 카드에 담을 행들 (`CHALLAListRow`).
    public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .challaFont(ListSectionMetric.headerTypography)
                    .foregroundStyle(CHALLAColor.Label.normal)
                    // 헤더가 고정 높이라 줄바꿈되면 아래 행과 겹친다 (행과 동일한 정책).
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader) // 로터 헤더 탐색 대상 (탑 내비 타이틀과 동일 정책)
                    .frame(height: ListSectionMetric.headerLineBox, alignment: .center)
                    .padding(.top, ListSectionMetric.headerTopPadding)
                    .padding(.bottom, ListSectionMetric.headerBottomPadding)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, ListSectionMetric.leadingPadding)
        .padding(.trailing, ListSectionMetric.trailingPadding)
        .padding(.vertical, ListSectionMetric.verticalPadding)
        .background {
            RoundedRectangle(cornerRadius: CHALLARadius.large)
                .fill(CHALLAColor.Background.level1)
        }
    }
}

// MARK: - Zeplin 실측값

private enum ListSectionMetric {

    /// 카드 안쪽 왼쪽 여백.
    static let leadingPadding: CGFloat = 24

    /// 카드 안쪽 오른쪽 여백.
    ///
    /// 왼쪽(24)보다 작지만 오타가 아니다 — `List / Arrow`·`List / Check` 컴포넌트 폭이 318로 고정이고
    /// 카드 폭이 358이라 24 + 318 + 16 으로 딱 맞아떨어진다.
    /// 두 컴포넌트 모두 우측 상자가 32로 같고 그 안 아이콘만 다르다(화살표 16 / 체크 22).
    /// 그래서 눈에 보이는 여백은 화살표 행이 16 + 8 = 24, 체크 행이 16 + 5 = 21로 시안 그대로다.
    static let trailingPadding: CGFloat = 16
    /// 카드 안쪽 위아래 여백.
    static let verticalPadding: CGFloat = 10

    static let headerTypography = CHALLATypography.body.xsmall.bold

    /// 헤더 글자 상자 높이 — 시안(Figma)의 줄 상자, 즉 타이포 토큰의 줄 높이 그대로.
    ///
    /// 높이를 못 박는 이유: SwiftUI `Text`는 폰트 고유 줄 높이로 그려지고
    /// 그 값은 시안의 줄 높이와 다르다 (SUIT 14pt는 약 17.7 — 토큰의 16이 아니다).
    /// 예전 구현은 "글자 상자 높이 == 줄 높이"라고 가정하고 위아래 패딩만 더해
    /// 44를 만들려 했지만, 실제로는 45.7이 나와 카드마다 1.7씩 부풀었다.
    /// 여기서 상자를 16으로 고정하면 헤더 블록은 16 + 16 + 12 = 44로 산술로 확정된다.
    ///
    /// 폰트가 상자보다 큰 만큼(약 0.85씩) 글자는 상자 밖으로 넘쳐 그려지는데,
    /// 이는 시안(Figma)이 줄 상자 안에 글자를 세로 중앙 정렬하는 방식과 같다.
    static let headerLineBox: CGFloat = ListSectionMetric.headerTypography.lineHeight

    /// 헤더 블록은 높이 44에 글자 상자가 위에서 16 내려온 자리에 있다 (아래 12).
    ///
    /// 큰 Dynamic Type에서 글자가 커져도 블록은 44로 유지된다 —
    /// 이 카드는 행 높이(52·74)·버튼·탑 내비까지 전부 시안 수치로 고정한 컴포넌트라
    /// 헤더만 늘어나면 카드 안에서 혼자 어긋난다. 확대 대응은 DS 전체가 함께 결정할 문제다.
    /// 다만 상자를 자르지 않으므로(`clipped` 없음) 글자는 위 16 · 아래 12의 빈 자리로
    /// 번져 나가며 읽히고, 접근성 크기에서 곧바로 잘려 사라지지는 않는다.
    static let headerTopPadding: CGFloat = 16

    static let headerBottomPadding: CGFloat = 12
}

#Preview {
    @Previewable @State var isOn = true

    ScrollView {
        VStack(spacing: 16) {
            CHALLAListSection("앱 설정") {
                CHALLAListRow("테마", icon: .palette, accessory: .arrow(value: "레몬에이드")) {}
                CHALLAListRow("알림", icon: .bellSimple) {}
            }

            CHALLAListSection("계정") {
                CHALLAListRow("계정 관리", icon: .profile) {}
            }

            CHALLAListSection {
                CHALLAListRow("레몬에이드", icon: .circle, iconColor: CHALLAColor.Primary.yellow,
                              accessory: .check(isSelected: true)) {}
                CHALLAListRow("라즈베리", icon: .circle, iconColor: CHALLAColor.Primary.pink,
                              accessory: .check(isSelected: false)) {}
            }

            CHALLAListSection {
                CHALLAListRow("서비스 알림", description: "인화 대기, 인화 완료 등", isOn: $isOn)
            }
        }
        .padding(.horizontal, 16)
    }
    .background(CHALLAColor.Background.surface)
}
