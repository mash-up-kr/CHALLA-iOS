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
            // .photoDomain: 사진 그리드가 인화된 사진 목록을 조회한다 (ARCHITECTURE.md — 결과 그리드는 방 상세가 흡수).
            // .shootEntry: 사진 찍기 버튼이 카메라 진입 준비(목록·LUT·권한)를 홈과 공유한다.
            // .photoLibrary: 커버 사진을 고르기 전에 사진첩 권한을 묻는다.
            // .imageKit: 고른 사진을 카드 크기로 다운샘플해 저장하고, 인화 완료 안내가 필름에 실릴 사진을 미리 받는다.
            // .roomCoverUI: 커버 색·스티커를 디자인 시스템 토큰으로 옮기는 매핑을 홈과 공유한다.
            dependencies: [
                .roomDomain, .photoDomain, .shootEntry, .photoLibrary, .imageKit,
                .composableArchitecture, .designSystem, .roomCoverUI
            ]
        ),
        .target(
            name: "RoomDetailFeatureTests",
            destinations: Environment.destinations,
            product: .unitTests,
            bundleId: "\(Environment.bundleIdPrefix).roomdetailfeaturetests",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .default,
            sources: ["Tests/**"],
            // 테스트가 Room·RoomDetail·Photo 값을 직접 만들어 리듀서에 넣는다.
            dependencies: [
                .target(name: "RoomDetailFeature"), .roomDomain, .photoDomain, .shootEntry,
                .photoLibrary, // 촬영 진입·커버 사진 선택이 묻는 사진첩 권한을 테스트가 값으로 갈아끼운다
                .imageKit, // 모듈 타깃이 CHALLAImageKit을 쓰므로 테스트 링크에도 필요하다
                .composableArchitecture
            ]
        )
    ]
)
