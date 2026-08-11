import ProjectDescription
import ProjectDescriptionHelpers

/// 테스트 타깃이 RoomDomain을 직접 import해야 해서(엔티티로 검증) makeModule 대신 직접 구성한다.
let project = Project(
    name: "RoomData",
    organizationName: Environment.organizationName,
    options: .options(
        defaultKnownRegions: ["en", "ko"],
        developmentRegion: "ko"
    ),
    settings: .challaBase(), // Swift 6 언어 모드
    targets: [
        .makeModuleTarget(
            name: "RoomData",
            dependencies: [.roomDomain, .network] // .network: DefaultRoomRepository가 HTTPClient로 서버를 부른다
        ),
        .target(
            name: "RoomDataTests",
            destinations: Environment.destinations,
            product: .unitTests,
            bundleId: "\(Environment.bundleIdPrefix).roomdatatests",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .default,
            sources: ["Tests/**"],
            // .roomDomain: 테스트가 Room 엔티티·RoomError로 저장소 동작을 검증한다.
            dependencies: [.target(name: "RoomData"), .roomDomain]
        )
    ]
)
