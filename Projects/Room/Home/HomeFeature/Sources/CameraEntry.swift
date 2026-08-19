import ComposableArchitecture
import PhotoDomain
import RoomDomain

/// 카메라 화면을 띄우는 데 필요한 재료 한 벌. 홈이 미리 받아 App에 넘긴다 —
/// 카메라 화면은 목록을 스스로 조회하지 않기 때문이다 (`CameraFeature` MODULE.md 참고).
public struct CameraEntry: Equatable, Sendable {

    /// 촬영 버튼을 누른 방. 카메라가 이 방을 고른 채로 열린다.
    public let roomID: Room.ID
    public let rooms: [ShootableRoom]
    public let filters: [CameraFilter]

    public init(roomID: Room.ID, rooms: [ShootableRoom], filters: [CameraFilter]) {
        self.roomID = roomID
        self.rooms = rooms
        self.filters = filters
    }
}

/// 촬영 준비가 어긋나는 두 경우. 어느 쪽이냐에 따라 사용자가 할 일이 다르다 —
/// 권한은 설정 앱으로 가야 풀리고, 조회 실패는 다시 눌러 보면 된다.
public enum ShootPreparationError: Error, Equatable, Sendable {
    case cameraPermissionDenied
    case photoLibraryPermissionDenied
    case loadFailed(message: String)
}

extension Error {

    /// 방 조회는 `RoomError`, 필터 조회는 `PhotoError`로 실패한다 — 각자의 문구를 그대로 쓴다.
    var entryMessage: String {
        switch self {
        case let error as RoomError: error.userMessage
        case let error as PhotoError: error.userMessage
        default: PhotoError.unknown.userMessage
        }
    }
}

extension ShootPreparationError {

    // TODO: 얼럿 제목·버튼 문구는 임의 작성본 — 기획 정책 확정 시 교체할 것.
    var alert: AlertState<HomeFeature.Action.Alert> {
        switch self {
        case .cameraPermissionDenied:
            AlertState {
                TextState("카메라 접근이 필요해요")
            } actions: {
                ButtonState(action: .openSettingsTapped) { TextState("설정 열기") }
                ButtonState(role: .cancel) { TextState("나중에") }
            } message: {
                TextState("사진을 찍으려면 설정에서 카메라 접근을 허용해 주세요.")
            }

        // TODO: 임의 작성 문구 — 기획 확정 시 교체할 것.
        case .photoLibraryPermissionDenied:
            AlertState {
                TextState("사진첩 접근이 필요해요")
            } actions: {
                ButtonState(action: .openSettingsTapped) { TextState("설정 열기") }
                ButtonState(role: .cancel) { TextState("나중에") }
            } message: {
                TextState("촬영한 사진을 저장하려면 설정에서 사진첩 접근을 허용해 주세요.")
            }

        case let .loadFailed(message):
            AlertState {
                TextState("촬영을 시작하지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(message)
            }
        }
    }
}
