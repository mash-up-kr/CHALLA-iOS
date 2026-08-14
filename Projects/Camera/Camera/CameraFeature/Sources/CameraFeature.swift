import ComposableArchitecture
import CoreGraphics
import Foundation

@Reducer
public struct CameraFeature {

    @ObservableState
    public struct State: Equatable {

        public var rooms: IdentifiedArrayOf<CameraRoom>
        public var selectedRoomID: CameraRoom.ID?
        public var filters: IdentifiedArrayOf<CameraFilter>
        public var selectedFilterID: CameraFilter.ID?
        public var flashMode: CameraFlashMode
        public var cameraPosition: CameraPosition
        public var zoom: CameraZoom
        public var captureAvailability: CameraCaptureAvailability
        public var isRoomSelectionPresented: Bool
        public var toastMessage: String?

        public init(
            rooms: IdentifiedArrayOf<CameraRoom> = [],
            selectedRoomID: CameraRoom.ID? = nil,
            filters: IdentifiedArrayOf<CameraFilter> = CameraFilterCatalog.filters,
            selectedFilterID: CameraFilter.ID? = nil,
            flashMode: CameraFlashMode = .on,
            cameraPosition: CameraPosition = .back,
            zoom: CameraZoom = CameraZoom(),
            captureAvailability: CameraCaptureAvailability = .available,
            isRoomSelectionPresented: Bool = false,
            toastMessage: String? = nil
        ) {
            self.rooms = rooms
            self.selectedRoomID = selectedRoomID ?? rooms.first?.id
            self.filters = filters
            self.selectedFilterID = selectedFilterID ?? filters.first?.id
            self.flashMode = flashMode
            self.cameraPosition = cameraPosition
            self.zoom = zoom
            self.captureAvailability = captureAvailability
            self.isRoomSelectionPresented = isRoomSelectionPresented
            self.toastMessage = toastMessage
        }

        public var selectedRoom: CameraRoom? {
            selectedRoomID.flatMap { rooms[id: $0] }
        }
    }

    public enum Action: ViewAction, Equatable, Sendable {

        public enum ViewAction: Equatable, Sendable {
            case flashButtonTapped
            case cameraSwitchButtonTapped
            case shutterButtonTapped
            case zoomBadgeTapped
            case zoomMagnificationChanged(CGFloat)
            case zoomMagnificationEnded
            case filterSelected(CameraFilter.ID)
            case roomSelectButtonTapped
            case roomSelectionDismissed
            case roomSelected(CameraRoom.ID)
        }

        case view(ViewAction)

        case toastDismissed

        @CasePathable
        public enum Delegate: Equatable, Sendable {
            /// 셔터가 눌렸고 촬영이 허용된 상태. 실제 캡처·업로드는 API 연동 시 이 지점에 붙인다.
            case captureRequested(roomID: CameraRoom.ID, filterID: CameraFilter.ID?)
        }

        case delegate(Delegate)
    }

    public init() {}

    @Dependency(\.continuousClock) var clock

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.flashButtonTapped):
                state.flashMode.toggle()
                return .none

            case .view(.cameraSwitchButtonTapped):
                state.cameraPosition.toggle()
                return .none

            case .view(.shutterButtonTapped):
                if let toastMessage = state.captureAvailability.toastMessage {
                    state.toastMessage = toastMessage
                    return dismissToastAfterDelay()
                }
                guard let roomID = state.selectedRoomID else { return .none }
                return .send(.delegate(.captureRequested(roomID: roomID, filterID: state.selectedFilterID)))

            case .view(.zoomBadgeTapped):
                state.zoom.cycle()
                return .none

            case let .view(.zoomMagnificationChanged(magnification)):
                state.zoom.magnify(by: magnification)
                return .none

            case .view(.zoomMagnificationEnded):
                state.zoom.endMagnifying()
                return .none

            case let .view(.filterSelected(filterID)):
                guard state.filters[id: filterID] != nil else { return .none }
                state.selectedFilterID = filterID
                return .none

            case .view(.roomSelectButtonTapped):
                state.isRoomSelectionPresented = true
                return .none

            case .view(.roomSelectionDismissed):
                state.isRoomSelectionPresented = false
                return .none

            case let .view(.roomSelected(roomID)):
                guard state.rooms[id: roomID] != nil else { return .none }
                state.selectedRoomID = roomID
                state.isRoomSelectionPresented = false
                return .none

            case .toastDismissed:
                state.toastMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private enum CancelID { case toast }

    private static let toastDuration: Duration = .seconds(3)

    private func dismissToastAfterDelay() -> Effect<Action> {
        .run { [clock] send in // 비-Sendable self 대신 의존성 값만 캡처
            try await clock.sleep(for: Self.toastDuration)
            await send(.toastDismissed)
        }
        .cancellable(id: CancelID.toast, cancelInFlight: true)
    }
}
