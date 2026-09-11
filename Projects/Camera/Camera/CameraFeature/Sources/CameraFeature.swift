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
        public var flashMode: CameraFlashMode
        public var cameraPosition: CameraPosition
        public var zoom: CameraZoom
        public var toastMessage: String?
        /// 촬영 중이면 존재한다 — 셔터를 누른 순간 생겨서, 업로드가 끝나고 방 상세로 넘어갈 때까지 남는다.
        public var capture: CaptureProgress?
        /// 노출 중인 온보딩 안내 단계. nil이면 안내가 없다.
        public var coachMark: CameraCoachMark?
        /// 안내를 이미 시작했는지. 화면이 다시 그려져도 안내가 되풀이되지 않게 막는다.
        public var hasStartedCoachMark: Bool

        /// 방·필터는 진입 전에 받아 둔 것을 넘겨받는다 — 이 화면은 목록을 스스로 조회하지 않는다.
        /// 목록 조회에 실패하면 애초에 이 화면으로 넘어오지 않으므로, 빈 목록으로 들어오는 경우는 없다.
        ///
        /// - Parameters:
        ///   - rooms: 촬영 가능한 방 목록 (`GET /rooms/shootable`).
        ///   - filters: 서버 필터 목록 (`GET /shoots/camera-filters`). LUT까지 준비된 상태로 들어온다.
        ///   - selectedRoomID: 들어온 경로가 방을 지정할 때 넘긴다 (방 상세 → 사진 찍기). nil이면 첫 방.
        public init(
            rooms: IdentifiedArrayOf<ShootableRoom>,
            filters: IdentifiedArrayOf<CameraFilter>,
            selectedRoomID: ShootableRoom.ID? = nil,
            selectedFilterID: CameraFilter.ID? = nil,
            flashMode: CameraFlashMode = .off,
            cameraPosition: CameraPosition = .back,
            zoom: CameraZoom = CameraZoom(),
            toastMessage: String? = nil,
            coachMark: CameraCoachMark? = nil,
            hasStartedCoachMark: Bool = false
        ) {
            self.rooms = rooms
            self.selectedRoomID = selectedRoomID ?? rooms.first?.id
            self.filters = Self.withNoneFirst(filters)
            self.selectedFilterID = selectedFilterID ?? CameraFilter.none.id
            self.flashMode = flashMode
            self.cameraPosition = cameraPosition
            self.zoom = zoom
            self.toastMessage = toastMessage
            capture = nil
            self.coachMark = coachMark
            // 안내를 띄운 채로 시작하는 프리뷰·데모는 이미 시작한 것으로 본다.
            self.hasStartedCoachMark = hasStartedCoachMark || coachMark != nil
        }

        /// 무필터를 맨 앞에 고정한다 — 서버 목록에는 없고, 진입 시 선택돼 있는 필터다.
        private static func withNoneFirst(
            _ filters: IdentifiedArrayOf<CameraFilter>
        ) -> IdentifiedArrayOf<CameraFilter> {
            var filters = filters
            filters.remove(id: CameraFilter.none.id)
            filters.insert(CameraFilter.none, at: 0)
            return filters
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

        public var isCapturing: Bool {
            capture != nil
        }
    }

    /// 셔터를 누른 뒤 방 상세로 넘어가기까지 채워야 할 두 조건.
    /// 둘이 다 차야 넘어간다 — 업로드가 순식간에 끝나도 촬영 연출이 한 번은 보인다.
    public struct CaptureProgress: Equatable, Sendable {

        public var isMinimumDisplayElapsed = false
        public var uploadedRoomID: ShootableRoom.ID?
        /// 서버로 올라가는 촬영본 그대로. 연출이 도는 동안 뷰파인더가 이 사진을 고정해 보여준다.
        /// 도착 전(스틸 촬영 수백 ms)에는 nil이고, 그동안은 프리뷰가 얼어붙은 채로 버틴다.
        public var photoData: Data?

        public init(
            isMinimumDisplayElapsed: Bool = false,
            uploadedRoomID: ShootableRoom.ID? = nil,
            photoData: Data? = nil
        ) {
            self.isMinimumDisplayElapsed = isMinimumDisplayElapsed
            self.uploadedRoomID = uploadedRoomID
            self.photoData = photoData
        }

        public var isFinished: Bool {
            isMinimumDisplayElapsed && uploadedRoomID != nil
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
            case coachMarkActionTapped
            case closeButtonTapped
        }

        case view(ViewAction)

        /// 진입 후 안내를 띄우기까지의 뜸. 최초 진입이 아니면 오지 않는다.
        case coachMarkDelayElapsed

        case minimumCaptureDisplayElapsed

        /// 조립 지점이 하드웨어 촬영을 마치고 결과 JPEG을 돌려주는 통로.
        /// 방·필터는 `delegate(.captureRequested)`에 실었던 값을 그대로 되돌려 받는다 —
        /// 업로드 중 사용자가 방을 바꿔도 촬영 당시의 방으로 올라간다.
        case captureCompleted(roomID: ShootableRoom.ID, filterID: CameraFilter.ID, jpegData: Data)
        /// 조립 지점의 하드웨어 촬영·저장이 실패했다. 이 통로로 알려야 셔터가 다시 열린다.
        case captureFailed(message: String)
        case uploadResponse(roomID: ShootableRoom.ID, Result<Int, PhotoError>)
        case toastDismissed

        @CasePathable
        public enum Delegate: Equatable, Sendable {
            /// 셔터가 눌렸고 촬영이 허용된 상태. 조립 지점이 하드웨어 촬영 후
            /// `captureCompleted`로 JPEG을 되돌려주면 업로드까지 이어진다.
            case captureRequested(roomID: ShootableRoom.ID, filterID: CameraFilter.ID)
            /// 촬영본이 방에 올라갔고 연출도 끝났다 — 그 방의 상세로 넘어갈 차례. 전환은 App이 조립한다.
            case captureFinished(roomID: ShootableRoom.ID)
            /// 촬영을 그만두고 이전 화면으로 돌아간다. 어디로 돌아갈지는 App이 정한다.
            case closeRequested
        }

        case delegate(Delegate)
    }

    public init() {}

    @Dependency(\.continuousClock) var clock
    @Dependency(\.uploadPhotoUseCase) var uploadPhoto
    @Dependency(\.shouldShowCameraCoachMarkUseCase) var shouldShowCoachMark
    @Dependency(\.markCameraCoachMarkSeenUseCase) var markCoachMarkSeen

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.task):
                return startCoachMark(&state)

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
                // 앞선 촬영이 끝나기 전의 연타는 버린다. 촬영 불가 토스트보다 먼저 본다 —
                // 연타 중에 장수가 0이 되면 누른 만큼 토스트가 쌓인다.
                guard !state.isCapturing else { return .none }

                if let toastMessage = state.captureAvailability.toastMessage {
                    state.toastMessage = toastMessage
                    return dismissToastAfterDelay()
                }
                // 필터 없는 촬영은 없다 — 목록이 아직 안 왔으면 셔터를 흘려보낸다
                // (목록이 오는 즉시 첫 필터가 선택되므로 이 상태는 진입 직후 잠깐뿐이다).
                guard let roomID = state.selectedRoomID, let filterID = state.selectedFilterID else {
                    return .none
                }
                state.capture = CaptureProgress()
                return .merge(
                    .send(.delegate(.captureRequested(roomID: roomID, filterID: filterID))),
                    minimumCaptureDisplay()
                )

            case .minimumCaptureDisplayElapsed:
                state.capture?.isMinimumDisplayElapsed = true
                return finishCaptureIfReady(&state)

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

            // 업로드가 끝날 때까지 촬영 연출을 이어간다 — 이 화면의 다음 목적지는 방 상세라
            // 셔터를 다시 열 이유가 없다.
            case let .captureCompleted(roomID, filterID, jpegData):
                // 올릴 사진이 곧 연출에 띄울 사진이다 — 뷰파인더가 여기서부터 이 한 장에 고정된다.
                state.capture?.photoData = jpegData
                return upload(jpegData: jpegData, roomID: roomID, filterID: filterID)

            case let .captureFailed(message):
                state.capture = nil
                state.toastMessage = message
                return .merge(.cancel(id: CancelID.capture), dismissToastAfterDelay())

            case let .uploadResponse(roomID, .success(remainedPhotoCount)):
                if let room = state.rooms[id: roomID] {
                    state.rooms[id: roomID] = ShootableRoom(
                        id: room.id,
                        title: room.title,
                        remainedPhotoCount: remainedPhotoCount,
                        totalPhotoCount: room.totalPhotoCount
                    )
                }
                state.capture?.uploadedRoomID = roomID
                return finishCaptureIfReady(&state)

            case let .uploadResponse(_, .failure(error)):
                state.capture = nil
                state.toastMessage = error.userMessage
                return .merge(.cancel(id: CancelID.capture), dismissToastAfterDelay())

            case .toastDismissed:
                state.toastMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func upload(
        jpegData: Data,
        roomID: ShootableRoom.ID,
        filterID: CameraFilter.ID
    ) -> Effect<Action> {
        .run { [uploadPhoto] send in
            do {
                let remained = try await uploadPhoto.run(jpegData, roomID, filterID)
                await send(.uploadResponse(roomID: roomID, .success(remained)))
            } catch let error as PhotoError {
                await send(.uploadResponse(roomID: roomID, .failure(error)))
            } catch is CancellationError {
            } catch {
                await send(.uploadResponse(roomID: roomID, .failure(.unknown)))
            }
        }
    }

    private func minimumCaptureDisplay() -> Effect<Action> {
        .run { [clock] send in
            try await clock.sleep(for: Self.minimumCaptureDisplayDuration)
            await send(.minimumCaptureDisplayElapsed)
        }
        .cancellable(id: CancelID.capture, cancelInFlight: true)
    }

    private func finishCaptureIfReady(_ state: inout State) -> Effect<Action> {
        // 화면이 넘어갈 때까지 capture를 그대로 둔다 — 연출이 풀렸다가 전환되는 깜빡임을 막는다.
        guard let capture = state.capture, capture.isFinished, let roomID = capture.uploadedRoomID else {
            return .none
        }
        return .send(.delegate(.captureFinished(roomID: roomID)))
    }

    /// 최초 진입이면 잠깐 뜸을 들였다가 안내 1단계를 띄운다.
    /// 이미 본 적 있거나(기기 기록) 이번 화면에서 이미 시작했으면 아무것도 하지 않는다.
    private func startCoachMark(_ state: inout State) -> Effect<Action> {
        guard !state.hasStartedCoachMark else { return .none }
        state.hasStartedCoachMark = true
        return .run { [shouldShowCoachMark, clock] send in
            guard await shouldShowCoachMark.run() else { return }
            try await clock.sleep(for: CameraCoachMark.presentationDelay)
            await send(.coachMarkDelayElapsed)
        }
        .cancellable(id: CancelID.coachMark, cancelInFlight: true)
    }

    /// 안내를 끝까지 본 것으로 기록한다. 실패 개념이 없어 화면에 알리지 않는다.
    private func markCoachMarkAsSeen() -> Effect<Action> {
        .run { [markCoachMarkSeen] _ in
            await markCoachMarkSeen.run()
        }
    }

    private func dismissToastAfterDelay() -> Effect<Action> {
        .run { [clock] send in // 비-Sendable self 대신 의존성 값만 캡처
            try await clock.sleep(for: Self.toastDuration)
            await send(.toastDismissed)
        }
        .cancellable(id: CancelID.toast, cancelInFlight: true)
    }

    private enum CancelID { case toast, coachMark, capture }

    private static var toastDuration: Duration {
        .seconds(3)
    }

    private static var minimumCaptureDisplayDuration: Duration {
        .seconds(1)
    }
}
