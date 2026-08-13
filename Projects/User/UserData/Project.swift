import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "UserData",
    organizationName: Environment.organizationName,
    options: .options(
        defaultKnownRegions: ["en", "ko"],
        developmentRegion: "ko"
    ),
    settings: .challaBase(), // Swift 6 언어 모드
    targets: [
        .makeModuleTarget(
            name: "UserData",
            dependencies: [.userDomain, .network]
        ),
        .target(
            name: "UserDataTests",
            destinations: Environment.destinations,
            product: .unitTests,
            bundleId: "\(Environment.bundleIdPrefix).userdatatests",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .default,
            sources: ["Tests/**"],
            // .network: Tests/Support의 MockHTTPClient가 CHALLANetwork 타입을 직접 import한다.
            dependencies: [.target(name: "UserData"), .userDomain, .network]
        )
    ]
)
