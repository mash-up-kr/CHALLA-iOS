import ProjectDescription
import ProjectDescriptionHelpers

/// 테스트 타깃이 ComposableArchitecture(TestStore)를 직접 import해야 해서 makeModule 대신 직접 구성한다.
let project = Project(
    name: "RoomDetailFeature",
    organizationName: Environment.organizationName,
    options: .options(
        defaultKnownRegions: ["en", "ko"],
        developmentRegion: "ko"
    ),
    settings: .challaBase(), // Swift 6 언어 모드
    targets: [
        .makeModuleTarget(
            name: "RoomDetailFeature",
            dependencies: [.roomDomain, .composableArchitecture, .designSystem]
        ),
        .target(
            name: "RoomDetailFeatureTests",
            destinations: Environment.destinations,
            product: .unitTests,
            bundleId: "\(Environment.bundleIdPrefix).roomdetailfeaturetests",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .default,
            sources: ["Tests/**"],
            // .roomDomain: 테스트가 Room·RoomDetail로 리듀서 동작을 검증한다.
            dependencies: [.target(name: "RoomDetailFeature"), .roomDomain, .composableArchitecture]
        )
    ]
)
