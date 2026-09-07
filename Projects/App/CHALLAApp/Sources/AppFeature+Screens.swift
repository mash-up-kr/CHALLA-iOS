import CameraFeature
import CameraSession
import ChatRoomFeature
import ComposableArchitecture
import HomeFeature
import PhotoDetailFeature
import ProfileSetupFeature
import RoomDetailFeature
import RoomDomain
import SettingFeature
import ShootEntry
import UserDomain

// 화면 하나를 띄우는 데 필요한 값을 모은 구조체들 — 자식 Feature의 State와,
// 이전 화면으로 돌아갈 때 다시 쓸 값(프로필·방)을 함께 둔다.
//
// `AppFeature.State`가 enum이라 다음 화면으로 가면 이전 화면의 State는 사라진다.
// 그래서 뒤로가기로 이전 화면을 다시 만들 때 필요한 값을 각 Screen이 미리 들고 다닌다.
// 어느 delegate가 어느 Screen을 만들지는 `AppFeature.swift`의 "화면 전이" 부분이 정한다.

// MARK: - HomeScreen

public extension AppFeature {

    /// 홈 화면 State + 설정으로 넘길 프로필.
    ///
    /// `HomeFeature.State`는 인사말용 닉네임·이미지만 들고 있다. 설정·프로필 편집은 전체 `UserProfile`이
    /// 필요해서, 홈에 들어올 때 받은 프로필을 여기 함께 두었다가 설정 진입 때 넘긴다.
    @ObservableState
    struct HomeScreen: Equatable {
        public var profile: UserProfile
        public var home: HomeFeature.State

        public init(profile: UserProfile) {
            self.profile = profile
            self.home = HomeFeature.State(
                nickname: profile.nickname ?? "",
                profileImageURL: profile.imageURL
            )
        }
    }
}

// MARK: - RoomDetailScreen

public extension AppFeature {

    /// 방 상세 화면 State + 홈으로 돌아갈 때 쓸 프로필.
    ///
    /// `State`가 enum이라 방 상세로 오면 홈 State는 사라진다. 뒤로가기로 홈을 다시 만들 때
    /// 인사말에 쓸 프로필이 필요한데, 안 들고 오면 서버를 다시 조회해야 하고 그동안 화면이 빈다.
    /// 방 상세 화면 자체는 이 프로필을 쓰지 않는다 — 돌아갈 때까지 맡아두는 값이다.
    @ObservableState
    struct RoomDetailScreen: Equatable {
        public var profile: UserProfile
        public var roomDetail: RoomDetailFeature.State

        public init(profile: UserProfile, room: Room) {
            self.profile = profile
            self.roomDetail = RoomDetailFeature.State(room: room)
        }
    }
}

// MARK: - RoomSettingsScreen

public extension AppFeature {

    /// 방 설정 화면 State + 상세 복귀용 재료.
    ///
    /// `State`가 enum이라 설정으로 오면 상세 State는 사라진다. 뒤로가기로 상세를 다시 만들 때
    /// 필요한 방·프로필을 여기 맡아둔다 (RoomDetailScreen이 프로필을 맡아두는 것과 같은 이유).
    @ObservableState
    struct RoomSettingsScreen: Equatable {
        public var profile: UserProfile
        public var room: Room
        public var settings: RoomSettingsFeature.State

        public init(profile: UserProfile, room: Room) {
            self.profile = profile
            self.room = room
            self.settings = RoomSettingsFeature.State(roomID: room.id, title: room.title)
        }
    }
}

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

// MARK: - SettingScreen

public extension AppFeature {

    /// 설정 화면 State + 홈 복귀용 프로필.
    ///
    /// 프로필을 함께 두는 이유: 홈이 닉네임을 표시하는데, 설정에서 뒤로가면 재조회 없이 바로 그려야 한다.
    @ObservableState
    struct SettingScreen: Equatable {
        public var profile: UserProfile
        public var setting: SettingFeature.State

        public init(profile: UserProfile, setting: SettingFeature.State = .init()) {
            self.profile = profile
            self.setting = setting
        }
    }
}

// MARK: - ProfileEditScreen

public extension AppFeature {

    /// 프로필 편집 화면 State + 취소 시 복원할 프로필.
    @ObservableState
    struct ProfileEditScreen: Equatable {
        public var profile: UserProfile
        public var edit: ProfileSetupFeature.State

        public init(profile: UserProfile) {
            self.profile = profile
            self.edit = ProfileSetupFeature.State(
                mode: .edit,
                nickname: profile.nickname ?? "",
                remoteImageURL: profile.imageURL
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
