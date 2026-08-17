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
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Scope(state: \.camera, action: \.camera) {
            CameraFeature()
        }
        Reduce { state, action in
            switch action {
            case let .camera(.delegate(.captureRequested(roomID, filterID))):
                let flashMode = state.camera.flashMode
                return .run { send in
                    do {
                        let jpegData = try await cameraSession.captureAndSavePhoto(
                            flashMode: flashMode,
                            filterID: filterID
                        )
                        // 저장까지 끝난 촬영본을 feature에 돌려줘 업로드(장수 차감)로 잇는다.
                        await send(.camera(.captureCompleted(roomID: roomID, filterID: filterID, jpegData: jpegData)))
                    } catch {
                        await send(.captureFailed(error.localizedDescription))
                    }
                }

            case let .captureFailed(message):
                state.camera.toastMessage = message
                return .run { [clock] send in
                    try await clock.sleep(for: Self.toastDuration)
                    await send(.camera(.toastDismissed))
                }
                .cancellable(id: CancelID.captureFailureToast, cancelInFlight: true)

            case .camera:
                return .none
            }
        }
    }

    private enum CancelID { case captureFailureToast }

    /// CameraFeature의 촬영 불가 토스트와 같은 노출 시간.
    private static let toastDuration: Duration = .seconds(3)
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
