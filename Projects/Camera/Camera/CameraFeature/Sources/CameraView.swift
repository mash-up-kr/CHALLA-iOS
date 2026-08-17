import CHALLADesignSystem
import ComposableArchitecture
import PhotoDomain
import RoomDomain
import SwiftUI

/// 카메라 화면
///
/// 뷰파인더 → 조작 3버튼 → 필터 띠 순의 상단 묶음과, 방 버튼 + 남은 장수의 하단 묶음을 위아래로 벌려 놓는다.
/// 뷰는 상태 렌더링과 `send(...)` 전달만 한다 — 배율 계산·촬영 차단·토스트 수명은 전부 리듀서 책임이다.
///
/// 프리뷰 화면은 `preview` 슬롯으로 주입한다. AVFoundation 연동 전까지는 기본값인
/// `CameraPreviewPlaceholder`가 들어가고, 카메라가 붙으면 앱 조립 지점에서 실제 프리뷰를 넘긴다.
@ViewAction(for: CameraFeature.self)
public struct CameraView<Preview: View>: View {

    public let store: StoreOf<CameraFeature>
    private let preview: () -> Preview

    /// 셔터 피드백(뷰파인더 블랙아웃 · 셔터 버튼 축소) 트리거. 리듀서 상태로 두기엔
    /// 화면 연출일 뿐이라 뷰 로컬 상태로만 관리한다.
    @State private var isShutterFeedbackActive = false

    public init(store: StoreOf<CameraFeature>, @ViewBuilder preview: @escaping () -> Preview) {
        self.store = store
        self.preview = preview
    }

    public var body: some View {
        content
            .task { await send(.task).finish() }
    }

    private var content: some View {
        GeometryReader { proxy in
            ZStack {
                VStack(spacing: 0) {
                    topSection
                    Color.clear
                        .frame(height: CameraViewMetric.middleGap(
                            availableHeight: proxy.size.height,
                            width: proxy.size.width
                        ))
                    bottomSection
                }

                toast
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                coachMarkSnackBar
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        // ZStack 안에 넣으면(형제로 두면) 다른 형제들의 상단 SafeArea 회피가 함께 풀린다 —
        // 바깥쪽 background로 분리해야 topSection·bottomSection이 SafeArea를 정상적으로 존중한다.
        .background(CHALLAColor.Static.black.ignoresSafeArea())
        // 드로어를 SafeArea에 붙여 뒤에 남는 "N장 남음" 텍스트를 덮는다
        .challaDrawer(isPresented: roomSelectionBinding, bottomMargin: 0) {
            RoomSelectionDrawer(
                rooms: store.rooms,
                selectedRoomID: store.selectedRoomID,
                onSelect: { send(.roomSelected($0)) },
                onClose: { send(.roomSelectionDismissed) }
            )
        }
    }

    private var topSection: some View {
        VStack(spacing: CameraViewMetric.sectionSpacing) {
            CameraViewport(
                zoom: store.zoom,
                captureAvailability: store.captureAvailability,
                isShutterFlashing: isShutterFeedbackActive,
                isDimmed: store.isCoachMarkPresented,
                onZoomBadgeTap: { send(.zoomBadgeTapped) },
                onMagnificationChanged: { send(.zoomMagnificationChanged($0)) },
                onMagnificationEnded: { send(.zoomMagnificationEnded) },
                preview: preview
            )

            CameraControlBar(
                flashMode: store.flashMode,
                isCapturing: isShutterFeedbackActive,
                isShutterHighlighted: store.isCoachMarkPresented,
                onFlashTap: { send(.flashButtonTapped) },
                onShutterTap: handleShutterTap,
                onCameraSwitchTap: { send(.cameraSwitchButtonTapped) }
            )

            CameraFilterStrip(
                filters: store.filters,
                selectedFilterID: store.selectedFilterID,
                onSelect: { send(.filterSelected($0)) }
            )
            .coachMarkDimmed(store.isCoachMarkPresented)
        }
        .padding(.top, CameraViewMetric.screenTopPadding)
    }

    @ViewBuilder
    private var bottomSection: some View {
        if let room = store.selectedRoom {
            VStack(spacing: CameraViewMetric.bottomSpacing) {
                RoomSelectButton(roomName: room.title) {
                    send(.roomSelectButtonTapped)
                }
                RemainingCardsLabel(remaining: room.remainedPhotoCount, total: room.totalPhotoCount)
            }
            .padding(.horizontal, CameraViewMetric.bottomHorizontalPadding)
            .padding(.bottom, CameraViewMetric.screenBottomPadding)
            .coachMarkDimmed(store.isCoachMarkPresented)
        }
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

    /// 촬영 가능 여부와 무관하게 셔터를 눌렀다는 감각(블랙아웃 · 버튼 축소)부터 즉시 준다 —
    /// 실제 촬영 성공/차단 여부는 리듀서가 뒤이어 판단한다.
    private func handleShutterTap() {
        withAnimation(.easeOut(duration: 0.1)) {
            isShutterFeedbackActive = true
        }
        send(.shutterButtonTapped)

        Task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeIn(duration: 0.2)) {
                isShutterFeedbackActive = false
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

    /// DS 드로어는 `Binding<Bool>`을 받는다. 상태 변경은 리듀서만 하도록 닫힘만 액션으로 되돌린다.
    private var roomSelectionBinding: Binding<Bool> {
        Binding(
            get: { store.isRoomSelectionPresented },
            set: { isPresented in
                guard !isPresented else { return }
                send(.roomSelectionDismissed)
            }
        )
    }
}

public extension CameraView where Preview == CameraPreviewPlaceholder {

    init(store: StoreOf<CameraFeature>) {
        self.init(store: store) { CameraPreviewPlaceholder() }
    }
}

// MARK: - Figma 실측값

/// 참조하는 각 컴포넌트의 static let height가 View 프로토콜 준수로 MainActor에 격리돼 있다.
@MainActor
private enum CameraViewMetric {

    /// SafeArea(상태바·다이나믹 아일랜드) 아래 여백. 물리 화면 끝 기준 고정값을 쓰면
    /// SafeArea가 큰 기기(다이나믹 아일랜드 등)에서 베젤이 상태바에 파묻힌다 — 상단 SafeArea는 무시하지 않는다.
    static let screenTopPadding: CGFloat = 12
    /// 시안의 하단 콘텐츠 끝(y=804)은 홈 인디케이터 SafeArea(810)보다 6pt 안쪽이다.
    static let screenBottomPadding: CGFloat = 6
    static let sectionSpacing: CGFloat = 20
    static let bottomSpacing: CGFloat = 12
    static let bottomHorizontalPadding: CGFloat = 40
    static let toastTopInset: CGFloat = 112
    /// 안내 스낵바: 시안 366×50 @(12,752) — 좌우 12, 아래는 홈 인디케이터 세이프에어리어 안쪽 8.
    static let snackBarHorizontalMargin: CGFloat = 12
    static let snackBarBottomPadding: CGFloat = 8
    /// 상단 뭉치·하단 뭉치 사이 여백 상한. 시안(844pt 캔버스) 기준 여백은 약 157pt —
    /// 상한이 없으면 화면이 커질수록 이 여백만 한없이 늘어난다.
    static let middleGapMaximum: CGFloat = 160

    /// 상단 뭉치(뷰파인더+조작바+필터띠) 전체 높이. 각 컴포넌트가 공개한 높이를 그대로 더한다.
    static func topSectionHeight(forWidth width: CGFloat) -> CGFloat {
        screenTopPadding
            + CameraViewportLayout.height(forWidth: width)
            + sectionSpacing + CameraControlBar.height
            + sectionSpacing + CameraFilterStrip.height
    }

    static let bottomSectionHeight: CGFloat =
        RoomSelectButton.height + bottomSpacing + RemainingCardsLabel.heightEstimate + screenBottomPadding

    /// 상단·하단 뭉치를 제외한 나머지 세로 공간. 화면이 커질수록 무한히 늘어나지 않도록 상한을 둔다.
    static func middleGap(availableHeight: CGFloat, width: CGFloat) -> CGFloat {
        let usedHeight = topSectionHeight(forWidth: width) + bottomSectionHeight
        return min(middleGapMaximum, max(0, availableHeight - usedHeight))
    }
}

// MARK: - Preview

private extension CameraFeature.State {

    /// 촬영 가능 여부는 방의 남은 장수로 정해지므로, 소진 화면은 `remainedPhotoCount: 0`인 방으로 만든다.
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
