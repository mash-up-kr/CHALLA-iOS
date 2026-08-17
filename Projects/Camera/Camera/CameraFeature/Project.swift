import ProjectDescription
import ProjectDescriptionHelpers

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
            dependencies: [.composableArchitecture, .designSystem, .roomDomain, .photoDomain]
        ),
        .target(
            name: "CameraFeatureTests",
            destinations: Environment.destinations,
            product: .unitTests,
            bundleId: "\(Environment.bundleIdPrefix).camerafeature.tests",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [.target(name: "CameraFeature"), .composableArchitecture, .roomDomain, .photoDomain]
        )
    ]
)
