import ProjectDescription
import ProjectDescriptionHelpers

/// 리소스(필터 LUT .cube)가 있지만 makeModule의 "리소스=dynamic" 정책 대신 static framework로 직접 구성한다.
/// dynamic으로 만들면 정적인 TCA 계열 의존성이 이 dylib과 앱 바이너리에 각각 복제 링크되어,
/// @TaskLocal 기반 @Dependency 주입이 이미지 간에 갈라질 수 있기 때문 (LoginFeature와 같은 판단).
/// 리소스는 Tuist가 합성하는 리소스 번들 + Bundle.module 접근자로 그대로 동작한다.
let project = Project(
    name: "CameraFeature",
    organizationName: Environment.organizationName,
    options: .options(
        defaultKnownRegions: ["en", "ko"],
        developmentRegion: "ko"
    ),
    settings: .challaBase(), // Swift 6 언어 모드
    targets: [
        .target(
            name: "CameraFeature",
            destinations: Environment.destinations,
            product: .staticFramework,
            bundleId: "\(Environment.bundleIdPrefix).camerafeature",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .default,
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            dependencies: [.composableArchitecture, .designSystem]
        ),
        .target(
            name: "CameraFeatureTests",
            destinations: Environment.destinations,
            product: .unitTests,
            bundleId: "\(Environment.bundleIdPrefix).camerafeature.tests",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [.target(name: "CameraFeature"), .composableArchitecture]
        )
    ]
)
