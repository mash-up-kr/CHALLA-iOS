import CHALLADesignSystem
import SwiftUI

/// 필름 카메라 베젤 + 그 안의 뷰파인더.
/// 촬영이 막히면 프리뷰 대신 안내 문구를 띄우고 배율 조작도 감춘다.
struct CameraViewport<Preview: View>: View {

    let zoom: CameraZoom
    let captureAvailability: CameraCaptureAvailability
    /// 셔터를 누른 순간 뷰파인더를 잠깐 검게 덮는다 (촬영 피드백).
    let isShutterFlashing: Bool
    let onZoomBadgeTap: () -> Void
    let onMagnificationChanged: (CGFloat) -> Void
    let onMagnificationEnded: () -> Void
    @ViewBuilder let preview: () -> Preview

    var body: some View {
        viewport
            .overlay {
                CHALLAColor.Static.black
                    .opacity(isShutterFlashing ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .aspectRatio(ViewportMetric.viewportAspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: ViewportMetric.viewportRadius))
            .padding(ViewportMetric.bezelPadding)
            .background(bezel)
            .padding(.horizontal, ViewportMetric.bezelHorizontalMargin)
    }

    @ViewBuilder
    private var viewport: some View {
        if let message = captureAvailability.viewportMessage {
            blocked(message: message)
        } else {
            live
        }
    }

    private var live: some View {
        preview()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(zoom.factor)
            .contentShape(Rectangle()) // 확대 전 원래 프레임에서 핀치를 받는다
            .gesture(magnification)
            .overlay(alignment: .bottomTrailing) {
                zoomBadge
                    .padding(ViewportMetric.zoomBadgeInset)
            }
    }

    private func blocked(message: String) -> some View {
        CHALLAColor.Background.level1
            .overlay {
                Text(message)
                    .challaFont(.body.large.medium)
                    .foregroundStyle(CHALLAColor.Label.disabled)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ViewportMetric.bezelPadding)
            }
            .overlay {
                RoundedRectangle(cornerRadius: ViewportMetric.viewportRadius)
                    .strokeBorder(
                        CHALLAColor.Line.normal,
                        style: StrokeStyle(
                            lineWidth: ViewportMetric.viewportBorderWidth,
                            dash: ViewportMetric.viewportBorderDashPattern
                        )
                    )
            }
    }

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { onMagnificationChanged($0.magnification) }
            .onEnded { _ in onMagnificationEnded() }
    }

    private var zoomBadge: some View {
        Button(action: onZoomBadgeTap) {
            Text(zoom.label)
                .challaFont(.body.medium.bold)
                .foregroundStyle(CHALLAColor.Label.normal)
                .padding(.horizontal, ViewportMetric.zoomBadgeHorizontalPadding)
                .frame(height: ViewportMetric.zoomBadgeHeight)
                .background(Capsule().fill(CHALLAColor.Background.level4))
                .contentShape(Capsule().expandedToHitTarget(from: ViewportMetric.zoomBadgeHeight))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("확대 배율 \(zoom.label), 탭하면 다음 배율")
    }

    private var bezel: some View {
        RoundedRectangle(cornerRadius: ViewportMetric.bezelRadius)
            .fill(CHALLAColor.Static.black)
            .shadow(
                color: CHALLAColor.Static.black.opacity(ViewportMetric.bezelShadowOpacity),
                radius: ViewportMetric.bezelShadowRadius,
                y: ViewportMetric.bezelShadowOffsetY
            )
            .overlay {
                RoundedRectangle(cornerRadius: ViewportMetric.bezelRadius)
                    .inset(by: -ViewportMetric.bezelBorderWidth / 2) // 시안의 border position = outside
                    .stroke(CHALLAColor.Static.white, lineWidth: ViewportMetric.bezelBorderWidth)
            }
    }
}

/// 실제 카메라 프리뷰(AVFoundation)가 붙기 전까지 뷰파인더 자리를 채우는 대역.
public struct CameraPreviewPlaceholder: View {

    public init() {}

    public var body: some View {
        LinearGradient(
            colors: [CHALLAColor.Background.level4, CHALLAColor.Background.level2],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// `CameraViewport`는 제네릭이라 정적 멤버를 타입 추론 없이 부를 수 없다 —
/// `CameraView`가 상단 뭉치 높이를 계산할 때 이 네임스페이스로 우회해서 부른다.
enum CameraViewportLayout {

    /// 뷰파인더는 폭에서 종횡비로 유도되므로, 베젤 전체 높이도 폭이 있어야 계산된다.
    static func height(forWidth width: CGFloat) -> CGFloat {
        let viewportWidth = width - 2 * ViewportMetric.bezelHorizontalMargin - 2 * ViewportMetric.bezelPadding
        return viewportWidth / ViewportMetric.viewportAspectRatio + 2 * ViewportMetric.bezelPadding
    }
}

// MARK: - Figma 실측값

private enum ViewportMetric {
    static let bezelHorizontalMargin: CGFloat = 38.5
    static let bezelPadding: CGFloat = 24
    static let bezelRadius: CGFloat = 60
    static let bezelBorderWidth: CGFloat = 4
    static let bezelShadowOpacity: Double = 0.22
    static let bezelShadowOffsetY: CGFloat = 18
    /// Figma blur 111 ≈ SwiftUI shadow radius의 2배
    static let bezelShadowRadius: CGFloat = 55.5

    static let viewportAspectRatio: CGFloat = 265.0 / 353.0
    static let viewportRadius: CGFloat = 30
    static let viewportBorderWidth: CGFloat = 2
    /// 촬영 불가 상태의 점선 테두리 패턴. Zeplin에 dash 수치가 없어 `CHALLAFilmCard`의
    /// `beforeCapture` 패턴을 그대로 따른다 — 디자이너 검수로 확정한다.
    static let viewportBorderDashPattern: [CGFloat] = [4, 4]

    static let zoomBadgeHeight: CGFloat = 34
    static let zoomBadgeHorizontalPadding: CGFloat = 12
    static let zoomBadgeInset: CGFloat = 12
}
