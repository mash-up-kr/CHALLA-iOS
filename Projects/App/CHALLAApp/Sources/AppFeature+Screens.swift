import CameraFeature
import CameraSession
import ChatRoomFeature
import ComposableArchitecture
import PhotoDetailFeature
import RoomDomain
import ShootEntry
import UserDomain

// MARK: - PhotoDetailScreen

public extension AppFeature {

    /// 사진 상세 화면 State + 뒤로 갈 때 복원할 방·프로필.
    ///
    /// `State`가 enum이라 사진 상세로 오면 방 상세 State가 사라진다. 뒤로가기로 방 상세를 다시 만들 때
    /// 쓸 방과 프로필을 여기 맡아 둔다 (방 상세→홈 복귀가 프로필을 들고 다니는 것과 같은 이유).
    @ObservableState
    struct PhotoDetailScreen: Equatable {
        public var profile: UserProfile
        public var room: Room
        public var photoDetail: PhotoDetailFeature.State

        public init(profile: UserProfile, room: Room, initialPhotoID: String) {
            self.profile = profile
            self.room = room
            self.photoDetail = PhotoDetailFeature.State(
                roomID: room.id,
                roomTitle: room.title,
                // 리액션을 남기는 주체 = 지금 보는 사람. PhotoReaction.userID(String)와 맞춘다.
                currentUserID: String(profile.id),
                // 인화 완료 전이면 방 상세처럼 사진을 blur로 가린다.
                isPrinted: room.status == .printed,
                initialPhotoID: initialPhotoID
            )
        }
    }
}

// MARK: - CameraScreen

public extension AppFeature {

    /// 카메라 화면 State + 닫을 때 돌아갈 곳.
    ///
    /// 방·필터 목록은 진입 버튼(홈의 촬영 뱃지 · 방 상세의 사진 찍기)이 미리 받아 둔 것을 그대로 옮겨 담는다 —
    /// 카메라 화면은 목록을 스스로 조회하지 않는다.
    @ObservableState
    struct CameraScreen: Equatable {
        public var profile: UserProfile
        /// 어디서 들어왔는지. 카메라를 닫으면 여기로 되돌린다.
        public var origin: CameraOrigin
        /// 카메라 화면 + 실기기 촬영 배선(`CameraSession`).
        public var live: LiveCameraFeature.State

        public init(profile: UserProfile, entry: CameraEntry, origin: CameraOrigin) {
            self.profile = profile
            self.origin = origin
            live = LiveCameraFeature.State(
                camera: CameraFeature.State(
                    rooms: IdentifiedArray(uniqueElements: entry.rooms),
                    filters: IdentifiedArray(uniqueElements: entry.filters),
                    selectedRoomID: entry.roomID
                )
            )
        }
    }

    /// 카메라를 닫았을 때 돌아갈 화면. 방 상세로 돌아가려면 그 방이 필요해 함께 들고 있는다 —
    /// `State`가 enum이라 카메라로 오면 앞 화면의 State는 사라진다.
    enum CameraOrigin: Equatable {
        case home
        case roomDetail(Room)
    }
}

// MARK: - ChatScreen

public extension AppFeature {

    /// 방 채팅 화면 State + 뒤로 갈 때 복원할 방·프로필.
    ///
    /// `State`가 enum이라 채팅으로 오면 방 상세 State가 사라진다. 뒤로가기로 방 상세를 다시 만들 때
    /// 쓸 방과 프로필을 여기 맡아 둔다 (PhotoDetailScreen과 같은 이유).
    @ObservableState
    struct ChatScreen: Equatable {
        public var profile: UserProfile
        public var room: Room
        public var chat: ChatRoomFeature.State

        public init(profile: UserProfile, room: Room) {
            self.profile = profile
            self.room = room
            self.chat = ChatRoomFeature.State(
                roomID: room.id,
                roomTitle: room.title,
                // 내 메시지(오른쪽 흰 버블) 판별 기준. 서버가 userId를 주면 그때 교체한다.
                currentUserNickname: profile.nickname ?? ""
            )
        }
    }
}
