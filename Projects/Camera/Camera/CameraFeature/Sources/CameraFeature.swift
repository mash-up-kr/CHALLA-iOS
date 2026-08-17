import ComposableArchitecture
import CoreGraphics
import Foundation
import PhotoDomain
import RoomDomain

@Reducer
public struct CameraFeature {

    @ObservableState
    public struct State: Equatable {

        public var rooms: IdentifiedArrayOf<ShootableRoom>
        public var selectedRoomID: ShootableRoom.ID?
        public var filters: IdentifiedArrayOf<CameraFilter>
        public var selectedFilterID: CameraFilter.ID?
        /// LUT 다운로드·등록까지 끝난 필터. 조립 지점(데모앱·CHALLAApp)이 이 집합의 변화를 보고
        /// 프리뷰 필터를 다시 적용한다 — 선택 시점에 LUT가 아직 안 내려온 경우를 잡는다.
        public var preparedFilterIDs: Set<CameraFilter.ID>
        public var flashMode: CameraFlashMode
        public var cameraPosition: CameraPosition
        public var zoom: CameraZoom
        public var isRoomSelectionPresented: Bool
        public var toastMessage: String?
        /// 노출 중인 온보딩 안내 단계. nil이면 안내가 없다.
        public var coachMark: CameraCoachMark?
        /// 안내를 이미 시작했는지. 화면이 다시 그려져도 안내가 되풀이되지 않게 막는다.
        public var hasStartedCoachMark: Bool

        /// 방·필터는 진입 전에 받아 둔 것을 넘겨받는다 — 이 화면은 목록을 스스로 조회하지 않는다.
        /// 목록 조회에 실패하면 애초에 이 화면으로 넘어오지 않으므로, 빈 목록으로 들어오는 경우는 없다.
        ///
        /// - Parameters:
        ///   - rooms: 촬영 가능한 방 목록 (`GET /rooms/shootable`).
        ///   - filters: 서버 필터 목록 (`GET /shoots/camera-filters`). LUT 파일은 이 화면이 내려받는다.
        ///   - selectedRoomID: 들어온 경로가 방을 지정할 때 넘긴다 (방 상세 → 사진 찍기). nil이면 첫 방.
        public init(
            rooms: IdentifiedArrayOf<ShootableRoom>,
            filters: IdentifiedArrayOf<CameraFilter>,
            selectedRoomID: ShootableRoom.ID? = nil,
            selectedFilterID: CameraFilter.ID? = nil,
            preparedFilterIDs: Set<CameraFilter.ID> = [],
            flashMode: CameraFlashMode = .on,
            cameraPosition: CameraPosition = .back,
            zoom: CameraZoom = CameraZoom(),
            isRoomSelectionPresented: Bool = false,
            toastMessage: String? = nil,
            coachMark: CameraCoachMark? = nil,
            hasStartedCoachMark: Bool = false
        ) {
            self.rooms = rooms
            self.selectedRoomID = selectedRoomID ?? rooms.first?.id
            self.filters = filters
            self.selectedFilterID = selectedFilterID ?? filters.first?.id
            self.preparedFilterIDs = preparedFilterIDs
            self.flashMode = flashMode
            self.cameraPosition = cameraPosition
            self.zoom = zoom
            self.isRoomSelectionPresented = isRoomSelectionPresented
            self.toastMessage = toastMessage
            self.coachMark = coachMark
            // 안내를 띄운 채로 시작하는 프리뷰·데모는 이미 시작한 것으로 본다.
            self.hasStartedCoachMark = hasStartedCoachMark || coachMark != nil
        }

        public var selectedRoom: ShootableRoom? {
            selectedRoomID.flatMap { rooms[id: $0] }
        }

        /// 촬영 가능 여부는 선택된 방의 남은 장수만으로 정해진다 — 따로 들고 있으면 방과 어긋난다.
        public var captureAvailability: CameraCaptureAvailability {
            guard let selectedRoom else { return .available }
            return selectedRoom.remainedPhotoCount > 0 ? .available : .noCardsLeft
        }

        public var isCoachMarkPresented: Bool {
            coachMark != nil
        }
    }

    public enum Action: ViewAction, Equatable, Sendable {

        public enum ViewAction: Equatable, Sendable {
            case task
            case flashButtonTapped
            case cameraSwitchButtonTapped
            case shutterButtonTapped
            case zoomBadgeTapped
            case zoomMagnificationChanged(CGFloat)
            case zoomMagnificationEnded
            case filterSelected(CameraFilter.ID)
            case roomSelectButtonTapped
            case roomSelectionDismissed
            case roomSelected(ShootableRoom.ID)
            case coachMarkActionTapped
            case closeButtonTapped
        }

        case view(ViewAction)

        /// 진입 후 안내를 띄우기까지의 뜸. 최초 진입이 아니면 오지 않는다.
        case coachMarkDelayElapsed

        /// LUT가 카탈로그에 등록됐다 — 실패한 필터는 이 액션이 오지 않고 무보정 통과로 남는다.
        case filterLUTPrepared(CameraFilter.ID)
        /// 조립 지점이 하드웨어 촬영을 마치고 결과 JPEG을 돌려주는 통로.
        /// 방·필터는 `delegate(.captureRequested)`에 실었던 값을 그대로 되돌려 받는다 —
        /// 업로드 중 사용자가 방을 바꿔도 촬영 당시의 방으로 올라간다.
        case captureCompleted(roomID: ShootableRoom.ID, filterID: CameraFilter.ID, jpegData: Data)
        case uploadResponse(roomID: ShootableRoom.ID, Result<Int, PhotoError>)
        case toastDismissed

        @CasePathable
        public enum Delegate: Equatable, Sendable {
            /// 셔터가 눌렸고 촬영이 허용된 상태. 조립 지점이 하드웨어 촬영 후
            /// `captureCompleted`로 JPEG을 되돌려주면 업로드까지 이어진다.
            case captureRequested(roomID: ShootableRoom.ID, filterID: CameraFilter.ID)
            /// 촬영을 그만두고 이전 화면으로 돌아간다. 어디로 돌아갈지는 App이 정한다.
            case closeRequested
        }

        case delegate(Delegate)
    }

    public init() {}

    @Dependency(\.continuousClock) var clock
    @Dependency(\.loadFilterLUTUseCase) var loadFilterLUT
    @Dependency(\.uploadPhotoUseCase) var uploadPhoto
    @Dependency(\.shouldShowCameraCoachMarkUseCase) var shouldShowCoachMark
    @Dependency(\.markCameraCoachMarkSeenUseCase) var markCoachMarkSeen

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.task):
                return .merge(prepareLUTs(for: state.filters), startCoachMark(&state))

            case .coachMarkDelayElapsed:
                state.coachMark = .first
                return .none

            case .view(.coachMarkActionTapped):
                state.coachMark = state.coachMark?.next
                // 마지막 단계까지 넘겼다 — 다음 진입부터는 띄우지 않도록 기록한다.
                guard state.coachMark == nil else { return .none }
                return markCoachMarkAsSeen()

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
                // 필터 없는 촬영은 없다 — 목록이 아직 안 왔으면 셔터를 흘려보낸다
                // (목록이 오는 즉시 첫 필터가 선택되므로 이 상태는 진입 직후 잠깐뿐이다).
                guard let roomID = state.selectedRoomID, let filterID = state.selectedFilterID else {
                    return .none
                }
                return .send(.delegate(.captureRequested(roomID: roomID, filterID: filterID)))

            case .view(.closeButtonTapped):
                return .send(.delegate(.closeRequested))

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

            case let .filterLUTPrepared(filterID):
                state.preparedFilterIDs.insert(filterID)
                return .none

            case let .captureCompleted(roomID, filterID, jpegData):
                return upload(jpegData: jpegData, roomID: roomID, filterID: filterID)

            case let .uploadResponse(roomID, .success(remainedPhotoCount)):
                if let room = state.rooms[id: roomID] {
                    state.rooms[id: roomID] = ShootableRoom(
                        id: room.id,
                        title: room.title,
                        remainedPhotoCount: remainedPhotoCount,
                        totalPhotoCount: room.totalPhotoCount
                    )
                }
                return .none

            case let .uploadResponse(_, .failure(error)):
                state.toastMessage = error.userMessage
                return dismissToastAfterDelay()

            case .toastDismissed:
                state.toastMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
