import CameraFeature
import ComposableArchitecture
import SwiftUI

/// `CameraView`의 `preview` 슬롯에 주입하는 실기기 카메라 프리뷰.
/// 세션 시작·정지는 이 뷰의 생명주기를 따르고, 카메라 전환·줌·필터는 `store` 상태 변화를 그대로 반영한다.
struct LiveCameraPreview: View {

    let session: CameraSessionController
    let store: StoreOf<CameraFeature>

    var body: some View {
        content
            .task {
                session.setPreviewFilter(id: store.selectedFilterID)
                await session.start(position: store.cameraPosition)
            }
            .onDisappear { session.stop() }
            .onChange(of: store.cameraPosition) { _, position in
                session.setCameraPosition(position)
            }
            .onChange(of: store.zoom.factor) { _, factor in
                session.setZoomFactor(factor)
            }
            .onChange(of: store.selectedFilterID) { _, filterID in
                session.setPreviewFilter(id: filterID)
            }
            // 선택 시점에 LUT가 아직 안 내려온 경우 — 등록이 끝나면 같은 필터를 다시 적용한다.
            .onChange(of: store.preparedFilterIDs) { _, _ in
                session.setPreviewFilter(id: store.selectedFilterID)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch session.authorization {
        case .authorized:
            CameraFilteredPreviewView(source: session)
        case .denied:
            deniedMessage
        case .notDetermined:
            CameraPreviewPlaceholder()
        }
    }

    private var deniedMessage: some View {
        CameraPreviewPlaceholder()
            .overlay {
                Text("설정 앱에서 카메라 접근을 허용해주세요.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
            }
    }
}
