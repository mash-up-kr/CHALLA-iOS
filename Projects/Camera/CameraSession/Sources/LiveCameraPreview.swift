import CameraFeature
import ComposableArchitecture
import SwiftUI

/// `CameraView`의 `preview` 슬롯에 주입하는 실기기 카메라 프리뷰.
/// 세션 시작·정지는 이 뷰의 생명주기를 따르고, 카메라 전환·줌·필터는 `store` 상태 변화를 그대로 반영한다.
///
/// 권한은 여기서 묻지 않는다 — 이 화면에 들어왔다는 것은 진입 버튼이 이미 허용을 받아 뒀다는 뜻이다.
public struct LiveCameraPreview: View {

    private let session: CameraSessionController
    private let store: StoreOf<CameraFeature>

    public init(session: CameraSessionController, store: StoreOf<CameraFeature>) {
        self.session = session
        self.store = store
    }

    public var body: some View {
        CameraFilteredPreviewView(source: session)
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
    }
}
