import SwiftUI

/// 화면 하단에 좌우로 꽉 차게 떠서 안내하고, 오른쪽 액션으로 넘어가거나 닫는 배너.
///
/// 토스트(`CHALLAToast`)와 표면은 같지만 역할이 다르다 —
/// 토스트는 아이콘 + 문구로 결과를 알리고 스스로 사라지고, 스낵바는 액션을 눌러야 넘어간다.
/// 표시 위치·등장 애니메이션은 화면마다 달라서 이 컴포넌트가 정하지 않는다.
public struct CHALLASnackBar: View {

    /// 오른쪽 끝 텍스트 버튼 한 자리. 없으면 문구만 있는 스낵바가 된다.
    public struct Action {
        let title: String
        let handler: () -> Void

        public init(_ title: String, handler: @escaping () -> Void) {
            self.title = title
            self.handler = handler
        }
    }

    @Environment(\.challaTheme) private var theme

    private let message: String
    private let action: Action?

    public init(_ message: String, action: Action? = nil) {
        self.message = message
        self.action = action
    }

    public var body: some View {
        HStack(spacing: SnackBarMetric.contentSpacing) {
            Text(message)
                .challaFont(.body.small.medium)
                .foregroundStyle(CHALLAColor.Label.normal)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let action {
                actionButton(action)
            }
        }
        .challaFloatingSurface()
        .accessibilityElement(children: .contain)
    }

    /// Figma `textButton / Transparent / Small`과 같은 치수를 쓰되 글자만 강조색이다.
    /// `CHALLATextButton`은 transparent에 강조색 옵션이 없어 치수만 공유한다.
    private func actionButton(_ action: Action) -> some View {
        Button(action: action.handler) {
            Text(action.title)
                .challaFont(CHALLAButtonSize.small.typography)
                .foregroundStyle(theme.accent)
                .lineLimit(1)
                .padding(.horizontal, CHALLAButtonSize.small.horizontalPadding)
                .frame(height: CHALLAButtonSize.small.height)
                .contentShape(
                    RoundedRectangle(cornerRadius: CHALLAButtonSize.small.radius)
                        .expandedToHitTarget(from: CHALLAButtonSize.small.height)
                )
        }
        .buttonStyle(.plain)
        .layoutPriority(1) // 문구가 길어도 버튼은 줄어들지 않는다
    }
}

private enum SnackBarMetric {
    static let contentSpacing: CGFloat = 12
}

#Preview {
    VStack(spacing: 12) {
        CHALLASnackBar("셔터를 누르는 순간 장수가 차감돼요.", action: .init("다음") {})
        CHALLASnackBar("신중하게 셔터를 눌러 보세요.", action: .init("확인") {})
        CHALLASnackBar("액션 없이 문구만 있는 스낵바예요.")
        CHALLASnackBar(
            "한 줄에 담기지 않는 아주 긴 안내 문구가 들어왔을 때 어떻게 접히는지 확인한다.",
            action: .init("확인") {}
        )
    }
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .background(CHALLAColor.Background.surface)
}
