import ProjectDescription
import ProjectDescriptionHelpers

/// 테스트 타깃이 ComposableArchitecture(TestStore)를 직접 import해야 해서 makeModule 대신 직접 구성한다.
let project = Project(
    name: "HomeFeature",
    organizationName: Environment.organizationName,
    options: .options(
        defaultKnownRegions: ["en", "ko"],
        developmentRegion: "ko"
    ),
    settings: .challaBase(), // Swift 6 언어 모드
    targets: [
        .makeModuleTarget(
            name: "HomeFeature",
            // .shootEntry: 촬영 뱃지가 카메라 진입 준비(목록·LUT·권한)를 방 상세와 공유한다.
            // .roomCoverUI: 방 카드의 커버 스티커·색을 디자인 시스템으로 옮긴다 — 커버 수정 화면과 같은 매핑.
            dependencies: [.roomDomain, .roomCoverUI, .shootEntry, .composableArchitecture, .designSystem]
        ),
        .target(
            name: "HomeFeatureTests",
            destinations: Environment.destinations,
            product: .unitTests,
            bundleId: "\(Environment.bundleIdPrefix).homefeaturetests",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .default,
            sources: ["Tests/**"],
            // .roomDomain: 테스트가 Room 엔티티·RoomError로 리듀서 동작을 검증한다.
            dependencies: [
                .target(name: "HomeFeature"), .roomDomain, .photoDomain, .shootEntry,
                .photoLibrary, // 촬영 진입이 묻는 사진첩 권한을 테스트가 값으로 갈아끼운다
                .composableArchitecture
            ]
        )
    ]
)
