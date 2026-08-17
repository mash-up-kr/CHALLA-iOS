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
    }

    public init() {}

    @Dependency(\.cameraSession) var cameraSession

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
                        await send(.camera(.captureFailed(message: error.localizedDescription)))
                    }
                }

            case .camera:
                return .none
            }
        }
    }
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
