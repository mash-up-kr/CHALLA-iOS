import ProjectDescription
import ProjectDescriptionHelpers

// 테스트 타깃을 함께 두기 위해 makeModule 대신 Project를 직접 구성한다.
// (공용 makeModule(hasTests:) 헬퍼는 이슈 #8에서 진행 중 — 머지되면 이 파일도 그 형태로 정리한다.)
let project = Project(
    name: "Keychain",
    organizationName: Environment.organizationName,
    options: .options(
        defaultKnownRegions: ["en", "ko"],
        developmentRegion: "ko"
    ),
    settings: .challaBase(),         // Swift 6 언어 모드
    targets: [
        .makeModuleTarget(name: "Keychain"),           // 외부 의존 0 (Security는 시스템)

        // 키체인(SecItem)은 앱 엔타이틀먼트가 있어야 접근 가능해서, 호스트 없는 테스트 러너로 돌리면
        // errSecMissingEntitlement(-34018)로 전부 실패한다 → 빈 호스트 앱에 태워서 실행한다.
        .target(
            name: "KeychainTestHost",
            destinations: Environment.destinations,
            product: .app,
            bundleId: "\(Environment.bundleIdPrefix).keychaintesthost",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .extendingDefault(with: ["UILaunchScreen": .dictionary([:])]),
            sources: ["TestHost/**"]
        ),
        .target(
            name: "KeychainTests",
            destinations: Environment.destinations,
            product: .unitTests,
            bundleId: "\(Environment.bundleIdPrefix).keychaintests",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "Keychain"),
                .target(name: "KeychainTestHost")      // 앱에 호스트되어 키체인 접근 권한 획득
            ]
        )
    ]
)
