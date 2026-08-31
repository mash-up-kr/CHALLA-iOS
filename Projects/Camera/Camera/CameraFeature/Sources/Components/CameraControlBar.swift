import CHALLADesignSystem
import SwiftUI

/// 플래시 · 셔터 · 카메라 전환 3버튼 줄.
/// DS의 `CHALLAIconButton`은 사각(radius 8~12) 버튼이라 시안의 52pt 원형 버튼과 맞지 않아 여기서 구성한다.
struct CameraControlBar: View {

    /// `CameraView`가 상단 뭉치 전체 높이를 계산할 때 참조하는 이 컴포넌트의 외부 치수.
    static let height: CGFloat = 80

    @Environment(\.challaTheme) private var theme

    let flashMode: CameraFlashMode
    /// 셔터를 누른 순간 안쪽 흰 원이 살짝 작아졌다가 돌아온다 (탭 피드백).
    let isShutterPressed: Bool
    /// 안내 스낵바가 떠 있는 동안 셔터에 흰 글로우를 둘러 주목시킨다 (시안 camera_snackBar_1·2).
    let isShutterHighlighted: Bool
    /// 앞선 촬영이 끝날 때까지 셔터를 잠근다 (연타 방지).
    let isShutterEnabled: Bool
    let onFlashTap: () -> Void
    let onShutterTap: () -> Void
    let onCameraSwitchTap: () -> Void

    var body: some View {
        HStack(spacing: ControlBarMetric.spacing) {
            circleButton(
                icon: flashMode.icon,
                accessibilityLabel: flashMode.accessibilityLabel,
                action: onFlashTap
            )
            shutterButton
            circleButton(
                icon: .arrowsCounterClockwise,
                accessibilityLabel: "카메라 전환",
                action: onCameraSwitchTap
            )
        }
        .frame(height: Self.height)
    }

    private func circleButton(
        icon: CHALLAIcon,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            icon.image(size: .size24, color: CHALLAColor.Label.neutral)
                .frame(width: ControlBarMetric.circleButtonSize, height: ControlBarMetric.circleButtonSize)
                .background(Circle().fill(CHALLAColor.Background.level4))
                .contentShape(Circle().expandedToHitTarget(from: ControlBarMetric.circleButtonSize))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var shutterButton: some View {
        Button(action: onShutterTap) {
            Circle()
                .fill(CHALLAColor.Label.normal)
                .frame(width: ControlBarMetric.shutterInnerSize, height: ControlBarMetric.shutterInnerSize)
                .scaleEffect(isShutterPressed ? ControlBarMetric.shutterPressedScale : 1)
                .frame(width: ControlBarMetric.shutterOuterSize, height: ControlBarMetric.shutterOuterSize)
                .overlay {
                    Circle()
                        .strokeBorder(theme.accent, lineWidth: ControlBarMetric.shutterRingWidth)
                }
                .shadow(
                    color: CHALLAColor.Static.white
                        .opacity(isShutterHighlighted ? ControlBarMetric.shutterGlowOpacity : 0),
                    radius: ControlBarMetric.shutterGlowRadius
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // 잠긴 동안에도 색은 그대로 둔다 — 시안에 셔터 비활성 상태가 없고, 촬영은 곧 끝난다.
        .disabled(!isShutterEnabled)
        .accessibilityLabel("촬영")
    }
}

// MARK: - Figma 실측값

private enum ControlBarMetric {
    static let spacing: CGFloat = 24
    static let circleButtonSize: CGFloat = 52
    static let shutterOuterSize: CGFloat = 80
    static let shutterInnerSize: CGFloat = 64
    static let shutterRingWidth: CGFloat = 3.33
    /// 셔터를 누르면 안쪽 흰 원이 이 비율까지 줄었다가 돌아온다 — 시안 육안 근사값, 디자이너 검수로 확정한다.
    static let shutterPressedScale: CGFloat = 0.85

    /// 안내 스낵바 노출 중 셔터 강조 글로우 (시안 outer 0/0 blur20 rgba(255,255,255,0.5))
    static let shutterGlowRadius: CGFloat = 10
    static let shutterGlowOpacity: Double = 0.5
}

#Preview {
    VStack(spacing: 24) {
        CameraControlBar(
            flashMode: .on, isShutterPressed: false, isShutterHighlighted: false, isShutterEnabled: true,
            onFlashTap: {}, onShutterTap: {}, onCameraSwitchTap: {}
        )
        CameraControlBar(
            flashMode: .off, isShutterPressed: false, isShutterHighlighted: false, isShutterEnabled: true,
            onFlashTap: {}, onShutterTap: {}, onCameraSwitchTap: {}
        )
        CameraControlBar(
            flashMode: .on, isShutterPressed: true, isShutterHighlighted: false, isShutterEnabled: true,
            onFlashTap: {}, onShutterTap: {}, onCameraSwitchTap: {}
        )
        CameraControlBar(
            flashMode: .on, isShutterPressed: false, isShutterHighlighted: true, isShutterEnabled: true,
            onFlashTap: {}, onShutterTap: {}, onCameraSwitchTap: {}
        )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CHALLAColor.Static.black)
}
