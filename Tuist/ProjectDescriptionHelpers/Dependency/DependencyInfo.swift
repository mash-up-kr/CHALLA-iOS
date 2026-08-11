import ProjectDescription

/// 모듈 의존성 선언 헬퍼. 각 Project.swift는 `.project(target:path:)`를 직접 쓰지 않고 여기 값을 쓴다.
public extension TargetDependency {

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

    // MARK: - Photo

    static let photoDomain = TargetDependency.project(
        target: "PhotoDomain",
        path: .relativeToRoot("Projects/Photo/PhotoDomain")
    )
    static let photoDetailFeature = TargetDependency.project(
        target: "PhotoDetailFeature",
        path: .relativeToRoot("Projects/Photo/PhotoDetail/PhotoDetailFeature")
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
}
