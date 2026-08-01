import ProjectDescription
import ProjectDescriptionHelpers

/// 테스트 타깃을 함께 두기 위해 makeModule 대신 Project를 직접 구성한다.
/// (공용 makeModule(hasTests:) 헬퍼는 이슈 #8에서 진행 중 — 머지되면 이 파일도 그 형태로 정리한다.)
let project = Project(
    name: "LoginFeature",
    organizationName: Environment.organizationName,
    options: .options(
        defaultKnownRegions: ["en", "ko"],
        developmentRegion: "ko"
    ),
    settings: .challaBase(), // Swift 6 언어 모드
    targets: [
        // 리소스(소셜 아이콘)가 있지만 makeModuleTarget의 "리소스=dynamic" 정책 대신 static framework로 선언한다.
        // dynamic으로 만들면 정적인 AuthDomain·Dependencies가 이 dylib과 앱 바이너리(AuthData 경유)에
        // 각각 복제 링크되어, @TaskLocal 기반 @Dependency 주입이 이미지 간에 갈라질 수 있기 때문.
        // 리소스는 Tuist가 합성하는 리소스 번들 + Bundle.module 접근자로 그대로 동작한다.
        .target(
            name: "LoginFeature",
            destinations: Environment.destinations,
            product: .staticFramework,
            bundleId: "\(Environment.bundleIdPrefix).loginfeature",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .default,
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            dependencies: [.authDomain, .composableArchitecture, .designSystem]
        ),
        .target(
            name: "LoginFeatureTests",
            destinations: Environment.destinations,
            product: .unitTests,
            bundleId: "\(Environment.bundleIdPrefix).loginfeaturetests",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [.target(name: "LoginFeature"), .composableArchitecture]
        )
    ]
)
