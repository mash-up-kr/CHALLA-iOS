import ProjectDescription
import ProjectDescriptionHelpers

/// 테스트 타깃을 함께 두기 위해 makeModule 대신 Project를 직접 구성한다.
/// (공용 makeModule(hasTests:) 헬퍼는 이슈 #8에서 진행 중 — 머지되면 이 파일도 그 형태로 정리한다.)
let project = Project(
    name: "AuthData",
    organizationName: Environment.organizationName,
    options: .options(
        defaultKnownRegions: ["en", "ko"],
        developmentRegion: "ko"
    ),
    settings: .challaBase(), // Swift 6 언어 모드
    targets: [
        .makeModuleTarget(
            name: "AuthData",
            dependencies: [
                .authDomain, .network, .keychain,
                .kakaoSDKCommon, .kakaoSDKAuth, .kakaoSDKUser
            ]
        ),
        .target(
            name: "AuthDataTests",
            destinations: Environment.destinations,
            product: .unitTests,
            bundleId: "\(Environment.bundleIdPrefix).authdatatests",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .default,
            sources: ["Tests/**"],
            // .networkTesting: 공용 MockHTTPClient. .network: 테스트가 NetworkError·Response를 직접 만든다.
            // .keychain: KeychainTokenStoreTests가 Keychain 프로토콜을 목으로 끼운다.
            dependencies: [.target(name: "AuthData"), .authDomain, .network, .networkTesting, .keychain]
        )
    ]
)
