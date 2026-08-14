import CHALLADesignSystem
import SwiftUI

/// 플래시 · 셔터 · 카메라 전환 3버튼 줄.
/// DS의 `CHALLAIconButton`은 사각(radius 8~12) 버튼이라 시안의 52pt 원형 버튼과 맞지 않아 여기서 구성한다.
struct CameraControlBar: View {

    /// `CameraView`가 상단 뭉치 전체 높이를 계산할 때 참조하는 이 컴포넌트의 외부 치수.
    static let height: CGFloat = 80

    let flashMode: CameraFlashMode
    /// 셔터를 누른 순간 안쪽 흰 원이 살짝 작아졌다가 돌아온다 (촬영 피드백).
    let isCapturing: Bool
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
                .scaleEffect(isCapturing ? ControlBarMetric.shutterPressedScale : 1)
                .frame(width: ControlBarMetric.shutterOuterSize, height: ControlBarMetric.shutterOuterSize)
                .overlay {
                    Circle()
                        .strokeBorder(CHALLAColor.Primary.yellow, lineWidth: ControlBarMetric.shutterRingWidth)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
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
}

#Preview {
    VStack(spacing: 24) {
        CameraControlBar(flashMode: .on, isCapturing: false, onFlashTap: {}, onShutterTap: {}, onCameraSwitchTap: {})
        CameraControlBar(flashMode: .off, isCapturing: false, onFlashTap: {}, onShutterTap: {}, onCameraSwitchTap: {})
        CameraControlBar(flashMode: .on, isCapturing: true, onFlashTap: {}, onShutterTap: {}, onCameraSwitchTap: {})
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CHALLAColor.Static.black)
}
