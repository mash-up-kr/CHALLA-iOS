import ProjectDescription

/// 모듈 의존성 선언 헬퍼. 각 Project.swift는 `.project(target:path:)`를 직접 쓰지 않고 여기 값을 쓴다.
public extension TargetDependency {

    // MARK: - UI
    static let designSystem = TargetDependency.project(
        target: "CHALLADesignSystem",
        path: .relativeToRoot("Projects/UI/CHALLADesignSystem")
    )

    // MARK: - Network
    /// Data 레이어에서만 선언한다 (아키텍처 규칙 6).
    static let network = TargetDependency.project(
        target: "CHALLANetwork",
        path: .relativeToRoot("Projects/Network/CHALLANetwork")
    )

    // MARK: - Auth
    static let authDomain = TargetDependency.project(
        target: "AuthDomain",
        path: .relativeToRoot("Projects/Auth/AuthDomain")
    )
    /// 조립 지점(앱 · DIContainer · 데모앱)에서만 선언한다 (아키텍처 규칙 2).
    static let authData = TargetDependency.project(
        target: "AuthData",
        path: .relativeToRoot("Projects/Auth/AuthData")
    )
    static let loginFeature = TargetDependency.project(
        target: "LoginFeature",
        path: .relativeToRoot("Projects/Auth/Login/LoginFeature")
    )

    // MARK: - Core
    static let keychain = TargetDependency.project(
        target: "Keychain",
        path: .relativeToRoot("Projects/Core/Keychain")
    )

    // MARK: - External (Tuist/Package.swift 경유 — 변경 시 `tuist install` 재실행)
    static let composableArchitecture = TargetDependency.external(name: "ComposableArchitecture")
    /// TCA 전이 의존 — Domain이 `@DependencyClient` 키를 선언하는 데 쓴다.
    static let dependencies = TargetDependency.external(name: "Dependencies")
    static let dependenciesMacros = TargetDependency.external(name: "DependenciesMacros")
    static let kakaoSDKCommon = TargetDependency.external(name: "KakaoSDKCommon")
    static let kakaoSDKAuth = TargetDependency.external(name: "KakaoSDKAuth")
    static let kakaoSDKUser = TargetDependency.external(name: "KakaoSDKUser")
}
