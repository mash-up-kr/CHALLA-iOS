import CHALLADesignSystem
import SwiftUI

/// 상단 `+` 버튼 아래에 뜨는 메뉴.
struct PlusMenu: View {

    let onCreateRoom: () -> Void
    let onJoinRoom: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            item("방 만들기", action: onCreateRoom)
            Rectangle()
                .fill(CHALLAColor.Line.normal)
                .frame(height: MenuMetric.dividerHeight)
            item("방 입장하기", action: onJoinRoom)
        }
        .frame(width: MenuMetric.width)
        .background(CHALLAColor.Static.black)
        .clipShape(RoundedRectangle(cornerRadius: MenuMetric.cornerRadius))
    }

    private func item(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .challaFont(.body.xsmall.medium)
                .foregroundStyle(CHALLAColor.Label.subtle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(MenuMetric.itemPadding)
                // 행 전체를 탭 영역이 되게 한다. 없으면 글자 위만 눌린다.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Figma 실측값

private enum MenuMetric {
    static let width: CGFloat = 180
    static let itemPadding: CGFloat = 16
    static let cornerRadius: CGFloat = CHALLARadius.xlarge
    static let dividerHeight: CGFloat = 1
}

#Preview {
    PlusMenu(onCreateRoom: {}, onJoinRoom: {})
        .padding()
        .background(CHALLAColor.Background.surface)
}
