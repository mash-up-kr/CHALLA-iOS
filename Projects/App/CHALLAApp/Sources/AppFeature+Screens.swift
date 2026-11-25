import ComposableArchitecture
import Foundation
import ProfileSetupFeature
import RoomDomain
import SettingFeature
import UserDomain

// 화면 하나를 띄우는 데 필요한 값을 모은 구조체들 — 자식 Feature의 State와,
// 이전 화면으로 돌아갈 때 다시 쓸 값(프로필·방)을 함께 둔다.
//
// `AppFeature.State`가 enum이라 다음 화면으로 가면 이전 화면의 State는 사라진다.
// 그래서 뒤로가기로 이전 화면을 다시 만들 때 필요한 값을 각 Screen이 미리 들고 다닌다.
// 어느 delegate가 어느 Screen을 만들지는 `AppFeature.swift`의 "화면 전이" 부분이 정한다.
//
// 홈·방 상세·사진 상세·채팅·방 설정·커버 수정·카메라는 `MainFeature`로 옮겨 가 포장이 필요 없어졌다.
// 남은 Screen들도 단계 4에서 같은 길을 밟는다.

// MARK: - SplashScreen

public extension AppFeature {

    /// 스플래시(`launching`) 화면 State — 최소 노출 시간을 지키기 위한 게이트.
    ///
    /// 노출이 끝나기 전에 다음 화면이 정해지면 목적지를 맡아 두고,
    /// `splashMinimumHoldFinished`가 오는 순간 그 화면으로 전이한다.
    @ObservableState
    struct SplashScreen: Equatable {
        /// 최소 노출이 이미 끝났는지. 로그인 직후 재진입처럼 다시 오래 보일 필요가 없으면 true로 시작한다.
        public var isMinimumHoldElapsed: Bool
        /// 최소 노출 중에 도착한 다음 화면.
        public var pendingDestination: SplashDestination?

        public init(
            isMinimumHoldElapsed: Bool = false,
            pendingDestination: SplashDestination? = nil
        ) {
            self.isMinimumHoldElapsed = isMinimumHoldElapsed
            self.pendingDestination = pendingDestination
        }
    }

    /// 스플래시가 끝난 뒤 이동할 화면. 화면 State는 실제로 전이하는 순간에 만든다.
    enum SplashDestination: Equatable {
        case forceUpdate(storeURL: URL?)
        case login
        case profileSetup
        case main(UserProfile)

        var isForceUpdate: Bool {
            if case .forceUpdate = self {
                return true
            }
            return false
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
        /// 홈으로 pop할 때 되살릴 직전 방 목록.
        public var homeCards: IdentifiedArrayOf<RoomCard>
        public var setting: SettingFeature.State

        public init(
            profile: UserProfile,
            setting: SettingFeature.State = .init(),
            homeCards: IdentifiedArrayOf<RoomCard> = []
        ) {
            self.profile = profile
            self.setting = setting
            self.homeCards = homeCards
        }
    }
}

// MARK: - ProfileEditScreen

public extension AppFeature {

    /// 프로필 편집 화면 State + 취소 시 복원할 프로필.
    @ObservableState
    struct ProfileEditScreen: Equatable {
        public var profile: UserProfile
        /// 설정을 거쳐 홈까지 되돌아갈 때 이어 줄 직전 방 목록.
        public var homeCards: IdentifiedArrayOf<RoomCard>
        public var edit: ProfileSetupFeature.State

        public init(profile: UserProfile, homeCards: IdentifiedArrayOf<RoomCard> = []) {
            self.profile = profile
            self.homeCards = homeCards
            self.edit = ProfileSetupFeature.State(
                mode: .edit,
                nickname: profile.nickname ?? "",
                remoteImageURL: profile.imageURL
            )
        }
    }
}

// MARK: - 현재 화면이 들고 있는 프로필

public extension AppFeature.State {

    /// 로그인 뒤 화면들이 들고 있는 프로필. 로그인 전 화면에서는 nil이다.
    /// 화면 밖(참여 토스트 등)에서 방을 열 때, 새 화면을 만들 프로필을 여기서 얻는다.
    var currentProfile: UserProfile? {
        switch self {
        case let .main(main): main.profile
        case let .setting(screen): screen.profile
        case let .profileEdit(screen): screen.profile
        case .launching, .login, .profileSetup, .forceUpdate: nil
        }
    }
}
