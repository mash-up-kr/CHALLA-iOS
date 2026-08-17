import CameraFeature
import ComposableArchitecture

/// `CameraFeature`를 감싸 `delegate(.captureRequested)`를 실제 촬영·저장으로 잇는다.
///
/// `CameraFeature` 자신은 카메라 하드웨어를 모른다 — 실 연동은 조립 지점 몫이라는 설계 때문에,
/// 실행 앱과 데모앱이 똑같이 필요한 이 배선만 따로 모아 둔다.
@Reducer
public struct LiveCameraFeature {

    @ObservableState
    public struct State: Equatable {
        public var camera: CameraFeature.State

        public init(camera: CameraFeature.State) {
            self.camera = camera
        }
    }

    public enum Action {
        case camera(CameraFeature.Action)
        /// 촬영·저장 실패를 카메라 화면의 토스트로 보여주기 위한 내부 액션.
        case captureFailed(String)
    }

    public init() {}

    @Dependency(\.cameraSession) var cameraSession
    @Dependency(\.continuousClock) var clock

    public var body: some ReducerOf<Self> {
        Scope(state: \.camera, action: \.camera) {
            CameraFeature()
        }
        Reduce { state, action in
            switch action {
            case let .camera(.delegate(.captureRequested(roomID, filterID))):
                let flashMode = state.camera.flashMode
                return .run { [cameraSession] send in // 비-Sendable self 대신 의존성 값만 캡처
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

// MARK: - 카메라 세션 주입

/// 리듀서와 프리뷰 뷰가 같은 세션을 봐야 해서 `@Dependency`로 한 인스턴스를 공유한다.
private enum CameraSessionDependencyKey: DependencyKey {
    static let liveValue = CameraSessionController()
}

public extension DependencyValues {
    var cameraSession: CameraSessionController {
        get { self[CameraSessionDependencyKey.self] }
        set { self[CameraSessionDependencyKey.self] = newValue }
    }
}
