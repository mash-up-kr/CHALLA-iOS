import CameraFeature
import ComposableArchitecture
import SwiftUI

/// `CameraView`의 `preview` 슬롯에 주입하는 실기기 카메라 프리뷰.
/// 세션 시작·정지는 이 뷰의 생명주기를 따르고, 카메라 전환·줌은 `store` 상태 변화를 그대로 반영한다.
struct LiveCameraPreview: View {

    let session: CameraSessionController
    let store: StoreOf<CameraFeature>

    var body: some View {
        content
            .task { await session.start(position: store.cameraPosition) }
            .onDisappear { session.stop() }
            .onChange(of: store.cameraPosition) { _, position in
                session.setCameraPosition(position)
            }
            .onChange(of: store.zoom.factor) { _, factor in
                session.setZoomFactor(factor)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch session.authorization {
        case .authorized:
            CameraPreviewView(session: session.session)
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
