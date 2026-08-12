import CameraFeature
import ComposableArchitecture

/// `CameraFeature`를 감싸 `.delegate(.captureRequested)`를 실제 촬영·저장으로 잇는다.
/// `CameraFeature` 자신은 카메라 하드웨어를 모른다 — 실 연동은 앱 조립 지점 몫이라는 설계를
/// 데모앱에서 그대로 따른다 (CameraFeature.Action.Delegate 주석 참고).
@Reducer
struct CameraDemoFeature {

    @ObservableState
    struct State: Equatable {
        var camera: CameraFeature.State
    }

    enum Action {
        case camera(CameraFeature.Action)
        /// 촬영·저장 실패를 기존 토스트 UI로 보여주기 위한 데모 전용 액션.
        case captureFailed(String)
    }

    @Dependency(\.cameraSession) var cameraSession

    var body: some ReducerOf<Self> {
        Scope(state: \.camera, action: \.camera) {
            CameraFeature()
        }
        Reduce { state, action in
            switch action {
            case .camera(.delegate(.captureRequested)):
                let flashMode = state.camera.flashMode
                return .run { send in
                    do {
                        try await cameraSession.captureAndSavePhoto(flashMode: flashMode)
                    } catch {
                        await send(.captureFailed(error.localizedDescription))
                    }
                }

            case let .captureFailed(message):
                state.camera.toastMessage = message
                return .run { send in
                    try await Task.sleep(for: .seconds(3))
                    await send(.camera(.toastDismissed))
                }

            case .camera:
                return .none
            }
        }
    }
}

private enum CameraSessionDependencyKey: DependencyKey {
    static let liveValue = CameraSessionController()
}

extension DependencyValues {
    var cameraSession: CameraSessionController {
        get { self[CameraSessionDependencyKey.self] }
        set { self[CameraSessionDependencyKey.self] = newValue }
    }
}
