import CHALLADesignSystem
import ComposableArchitecture
import PhotoDomain
import RoomDomain
import SwiftUI
import UIKit

/// 카메라 화면.
///
/// 셔터를 누르면 뷰파인더만 남기고 나머지가 사라지면서 뷰파인더가 화면 가운데로 내려간다 (시안 2).
/// 업로드가 끝나 방 상세로 넘어갈 때까지 그 상태가 유지된다.
@ViewAction(for: CameraFeature.self)
public struct CameraView<Preview: View>: View {

    public let store: StoreOf<CameraFeature>
    private let preview: () -> Preview

    @State private var isShutterPressed = false

    /// 촬영 연출 동안 뷰파인더에 고정할 촬영본. 리듀서가 든 JPEG을 한 번만 이미지로 푼다.
    @State private var capturedPhoto: Image?

    public init(store: StoreOf<CameraFeature>, @ViewBuilder preview: @escaping () -> Preview) {
        self.store = store
        self.preview = preview
    }

    public var body: some View {
        content
            .task { await send(.task).finish() }
            // 촬영본은 한 장뿐이라 있고 없음만 보면 된다 — Data 자체를 id로 두면 매 프레임 통째로 비교한다.
            .task(id: store.capture?.photoData != nil) { loadCapturedPhoto() }
    }

    private func loadCapturedPhoto() {
        guard let data = store.capture?.photoData else {
            capturedPhoto = nil
            return
        }
        capturedPhoto = UIImage(data: data).map(Image.init(uiImage:))
    }

    private var content: some View {
        GeometryReader { proxy in
            ZStack {
                VStack(spacing: 0) {
                    topSection(width: proxy.size.width, height: proxy.size.height)
                    Spacer(minLength: 0)
                    closeButton
                }

                toast
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                coachMarkSnackBar
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .animation(CameraViewMetric.captureAnimation, value: store.isCapturing)
        }
        .background(CHALLAColor.Static.black.ignoresSafeArea())
    }

    private func topSection(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: CameraViewMetric.sectionSpacing) {
            CameraViewport(
                zoom: store.zoom,
                captureAvailability: store.captureAvailability,
                isDimmed: store.isCoachMarkPresented,
                isCapturing: store.isCapturing,
                capturedPhoto: capturedPhoto,
                onZoomBadgeTap: { send(.zoomBadgeTapped) },
                onMagnificationChanged: { send(.zoomMagnificationChanged($0)) },
                onMagnificationEnded: { send(.zoomMagnificationEnded) },
                preview: preview
            )
            // 촬영 중에는 뷰파인더만 화면 한가운데로 내려간다 — 나머지는 제자리에서 사라진다.
            .offset(y: store.isCapturing ? CameraViewMetric.captureOffset(height: height, width: width) : 0)

            VStack(spacing: CameraViewMetric.sectionSpacing) {
                CameraControlBar(
                    flashMode: store.flashMode,
                    isShutterPressed: isShutterPressed,
                    isShutterHighlighted: store.isCoachMarkPresented,
                    isShutterEnabled: !store.isCapturing,
                    onFlashTap: { send(.flashButtonTapped) },
                    onShutterTap: handleShutterTap,
                    onCameraSwitchTap: { send(.cameraSwitchButtonTapped) }
                )

                VStack(spacing: CameraViewMetric.remainingCardsSpacing) {
                    if let room = store.selectedRoom {
                        RemainingCardsLabel(remaining: room.remainedPhotoCount, total: room.totalPhotoCount)
                    }
                    CameraFilterStrip(
                        filters: store.filters,
                        selectedFilterID: store.selectedFilterID,
                        onSelect: { send(.filterSelected($0)) }
                    )
                }
            }
            .coachMarkDimmed(store.isCoachMarkPresented)
            .modifier(HiddenWhileCapturing(isCapturing: store.isCapturing))
        }
        .padding(.top, CameraViewMetric.topPadding(height: height, width: width))
    }

    private var closeButton: some View {
        Button { send(.closeButtonTapped) } label: {
            CHALLAIcon.close.image(size: .size24, color: CHALLAColor.Label.neutral)
                .frame(width: CameraViewMetric.closeButtonSize, height: CameraViewMetric.closeButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("촬영 화면 닫기")
        .padding(.bottom, CameraViewMetric.screenBottomPadding)
        .coachMarkDimmed(store.isCoachMarkPresented)
        .modifier(HiddenWhileCapturing(isCapturing: store.isCapturing))
    }

    private var coachMarkSnackBar: some View {
        ZStack(alignment: .bottom) {
            if let coachMark = store.coachMark {
                CHALLASnackBar(
                    coachMark.message,
                    action: .init(coachMark.actionTitle) { send(.coachMarkActionTapped) }
                )
                .padding(.horizontal, CameraViewMetric.snackBarHorizontalMargin)
                .padding(.bottom, CameraViewMetric.snackBarBottomPadding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.coachMark)
    }

    private func handleShutterTap() {
        withAnimation(.easeOut(duration: 0.1)) {
            isShutterPressed = true
        }
        send(.shutterButtonTapped)

        Task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeIn(duration: 0.2)) {
                isShutterPressed = false
            }
        }
    }

    private var toast: some View {
        ZStack(alignment: .top) {
            if let message = store.toastMessage {
                CHALLAToast(message, icon: .error, variant: .negative)
                    .padding(.top, CameraViewMetric.toastTopInset)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.toastMessage)
    }
}

public extension CameraView where Preview == CameraPreviewPlaceholder {

    init(store: StoreOf<CameraFeature>) {
        self.init(store: store) { CameraPreviewPlaceholder() }
    }
}

/// 촬영 중 뷰파인더를 뺀 나머지를 지운다. 자리는 그대로 두고(레이아웃 유지) 보이지만 않게 한다 —
/// 사라지면서 위아래 간격이 접히면 뷰파인더가 두 번 움직이는 것처럼 보인다.
private struct HiddenWhileCapturing: ViewModifier {

    let isCapturing: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isCapturing ? 0 : 1)
            .allowsHitTesting(!isCapturing)
            .accessibilityHidden(isCapturing)
    }
}

@MainActor
private enum CameraViewMetric {

    /// 안전 영역 위에서 뷰파인더까지의 여백 (시안 1: 화면 top 100 − 안전 영역 47).
    static let screenTopPadding: CGFloat = 53
    static let screenBottomPadding: CGFloat = 6
    static let sectionSpacing: CGFloat = 20
    /// 남은 장수와 필터 띠 사이 (시안 1: 필터 글자 top 659 − 남은 장수 bottom 637).
    static let remainingCardsSpacing: CGFloat = 22
    static let toastTopInset: CGFloat = 112
    static let closeButtonSize: CGFloat = 52

    static let snackBarHorizontalMargin: CGFloat = 12
    static let snackBarBottomPadding: CGFloat = 8

    static let captureAnimation: Animation = .smooth(duration: 0.4)

    /// 화면이 시안(844)보다 짧으면 위 여백부터 줄인다 — 안 그러면 아래 내용이 잘린다.
    static func topPadding(height: CGFloat, width: CGFloat) -> CGFloat {
        min(screenTopPadding, max(0, height - contentHeight(forWidth: width)))
    }

    /// 위 여백을 뺀 나머지 — 뷰파인더부터 닫기 버튼까지.
    private static func contentHeight(forWidth width: CGFloat) -> CGFloat {
        CameraViewportLayout.height(forWidth: width)
            + sectionSpacing + CameraControlBar.height
            + sectionSpacing + RemainingCardsLabel.heightEstimate
            + remainingCardsSpacing + CameraFilterStrip.height
            + closeButtonSize + screenBottomPadding
    }

    /// 뷰파인더를 화면 세로 가운데로 옮기는 이동량 (시안 2).
    static func captureOffset(height: CGFloat, width: CGFloat) -> CGFloat {
        let bezelHeight = CameraViewportLayout.height(forWidth: width)
        return (height - bezelHeight) / 2 - topPadding(height: height, width: width)
    }
}

private extension CameraFeature.State {

    static func demo(
        remainedPhotoCount: Int = 3,
        flashMode: CameraFlashMode = .on,
        selectedFilterID: CameraFilter.ID? = nil,
        coachMark: CameraCoachMark? = nil
    ) -> Self {
        Self(
            rooms: [
                ShootableRoom(
                    id: -1,
                    title: "방이름방이름방이름3",
                    remainedPhotoCount: remainedPhotoCount,
                    totalPhotoCount: 48
                )
            ],
            filters: IdentifiedArray(uniqueElements: CameraFilter.previewFilters),
            selectedFilterID: selectedFilterID,
            flashMode: flashMode,
            coachMark: coachMark
        )
    }
}

#Preview("플래시 켜짐") {
    CameraView(store: Store(initialState: .demo()) { CameraFeature() })
}

#Preview("플래시 꺼짐 · Warm 필터") {
    CameraView(
        store: Store(initialState: .demo(flashMode: .off, selectedFilterID: "Warm")) { CameraFeature() }
    )
}

#Preview("안내 1단계 (camera_snackBar_1)") {
    CameraView(store: Store(initialState: .demo(coachMark: .shutterCost)) { CameraFeature() })
}

#Preview("안내 2단계 (camera_snackBar_2)") {
    CameraView(store: Store(initialState: .demo(coachMark: .shutterCaution)) { CameraFeature() })
}

#Preview("촬영 불가") {
    CameraView(store: Store(initialState: .demo(remainedPhotoCount: 0)) { CameraFeature() })
}
