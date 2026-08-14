import ProjectDescription

/// 모듈 의존성 선언 헬퍼. 각 Project.swift는 `.project(target:path:)`를 직접 쓰지 않고 여기 값을 쓴다.
public extension TargetDependency {

    // MARK: - Core

    /// CHALLAImageKit 모듈에 대한 의존성.
    static let imageKit = TargetDependency.project(
        target: "CHALLAImageKit",
        path: .relativeToRoot("Projects/Core/CHALLAImageKit")
    )

    // MARK: - UI

    static let designSystem = TargetDependency.project(
        target: "CHALLADesignSystem",
        path: .relativeToRoot("Projects/UI/CHALLADesignSystem")
    )

    // MARK: - Network

    static let network = TargetDependency.project(
        target: "CHALLANetwork",
        path: .relativeToRoot("Projects/Network/CHALLANetwork")
    )

    // MARK: - Auth

    static let authDomain = TargetDependency.project(
        target: "AuthDomain",
        path: .relativeToRoot("Projects/Auth/AuthDomain")
    )
    static let authData = TargetDependency.project(
        target: "AuthData",
        path: .relativeToRoot("Projects/Auth/AuthData")
    )
    static let loginFeature = TargetDependency.project(
        target: "LoginFeature",
        path: .relativeToRoot("Projects/Auth/Login/LoginFeature")
    )

    // MARK: - Room

    static let roomDomain = TargetDependency.project(
        target: "RoomDomain",
        path: .relativeToRoot("Projects/Room/RoomDomain")
    )
    static let roomData = TargetDependency.project(
        target: "RoomData",
        path: .relativeToRoot("Projects/Room/RoomData")
    )
    static let homeFeature = TargetDependency.project(
        target: "HomeFeature",
        path: .relativeToRoot("Projects/Room/Home/HomeFeature")
    )

    // MARK: - User

    static let userDomain = TargetDependency.project(
        target: "UserDomain",
        path: .relativeToRoot("Projects/User/UserDomain")
    )
    static let userData = TargetDependency.project(
        target: "UserData",
        path: .relativeToRoot("Projects/User/UserData")
    )
    static let profileSetupFeature = TargetDependency.project(
        target: "ProfileSetupFeature",
        path: .relativeToRoot("Projects/User/ProfileSetup/ProfileSetupFeature")
    )

    // MARK: - Setting

    static let settingDomain = TargetDependency.project(
        target: "SettingDomain",
        path: .relativeToRoot("Projects/Setting/SettingDomain")
    )
    static let settingData = TargetDependency.project(
        target: "SettingData",
        path: .relativeToRoot("Projects/Setting/SettingData")
    )
    static let settingFeature = TargetDependency.project(
        target: "SettingFeature",
        path: .relativeToRoot("Projects/Setting/Setting/SettingFeature")
    )

    // MARK: - Notification

    static let notificationDomain = TargetDependency.project(
        target: "NotificationDomain",
        path: .relativeToRoot("Projects/Notification/NotificationDomain")
    )
    static let notificationData = TargetDependency.project(
        target: "NotificationData",
        path: .relativeToRoot("Projects/Notification/NotificationData")
    )

    // MARK: - Core

    static let keychain = TargetDependency.project(
        target: "Keychain",
        path: .relativeToRoot("Projects/Core/Keychain")
    )
    static let photoLibrary = TargetDependency.project(
        target: "PhotoLibrary",
        path: .relativeToRoot("Projects/Core/PhotoLibrary")
    )

    // MARK: - External

    static let composableArchitecture = TargetDependency.external(name: "ComposableArchitecture")
    /// TCA 전이 의존 — Domain이 `@DependencyClient` 키를 선언하는 데 쓴다.
    static let dependencies = TargetDependency.external(name: "Dependencies")
    static let dependenciesMacros = TargetDependency.external(name: "DependenciesMacros")
    static let kakaoSDKCommon = TargetDependency.external(name: "KakaoSDKCommon")
    static let kakaoSDKAuth = TargetDependency.external(name: "KakaoSDKAuth")
    static let kakaoSDKUser = TargetDependency.external(name: "KakaoSDKUser")
    /// `FirebaseApp.configure()` — Messaging이 전이로 끌어오지만 import 하려면 직접 걸어야 한다.
    static let firebaseCore = TargetDependency.external(name: "FirebaseCore")
    /// FCM 토큰 발급·갱신 (`Messaging`, `MessagingDelegate`).
    static let firebaseMessaging = TargetDependency.external(name: "FirebaseMessaging")
}
