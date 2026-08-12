import CHALLADesignSystem
import SwiftUI

/// 하단의 현재 방 표시 겸 방 선택 드로어를 여는 버튼.
/// DS의 `CHALLATextButton`은 높이 40 · radius 10 고정이라 시안의 44pt 알약 버튼과 맞지 않아 여기서 구성한다.
struct RoomSelectButton: View {

    /// `CameraView`가 하단 뭉치 전체 높이를 계산할 때 참조하는 이 컴포넌트의 외부 치수.
    static let height: CGFloat = 44

    let roomName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: RoomSelectButtonMetric.spacing) {
                Text(roomName)
                    .challaFont(.body.xsmall.medium)
                    .foregroundStyle(CHALLAColor.Label.normal)
                    .lineLimit(1)
                CHALLAIcon.unfoldMore.image(size: .size20, color: CHALLAColor.Label.neutral)
            }
            .padding(.leading, RoomSelectButtonMetric.leadingPadding)
            .padding(.trailing, RoomSelectButtonMetric.trailingPadding)
            .frame(height: Self.height)
            .background(Capsule().fill(CHALLAColor.Background.level3))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("방 선택")
        .accessibilityValue(roomName)
    }
}

// MARK: - Figma 실측값

private enum RoomSelectButtonMetric {
    static let leadingPadding: CGFloat = 20
    static let trailingPadding: CGFloat = 12
    static let spacing: CGFloat = 5
}

#Preview {
    VStack(spacing: 12) {
        RoomSelectButton(roomName: "방이름방이름방이름3") {}
        RoomSelectButton(roomName: "짧은방") {}
        RoomSelectButton(roomName: "아주아주아주아주아주아주 긴 방 이름의 말줄임 확인") {}
            .padding(.horizontal, 40) // CameraView.bottomSection과 같은 화면 여백 — 미리보기 전용값
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CHALLAColor.Static.black)
}
