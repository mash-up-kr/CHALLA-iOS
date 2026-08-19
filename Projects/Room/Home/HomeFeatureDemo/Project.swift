import ProjectDescription
import ProjectDescriptionHelpers

/// 데모앱은 앱 조립 지점이므로 예외적으로 Data(Mock/실 구현)를 주입할 수 있다 (아키텍처 규칙 2의 유일한 예외).
let project = Project.makeAppProject(
    name: "HomeFeatureDemo",
    displayName: "CHALLA Home 데모",
    bundleId: "\(Environment.bundleIdPrefix).homefeature.demo",
    marketingVersion: "1.0.0",
    buildNumber: "1",
    additionalInfoPlist: [
        // 촬영 진입이 사진첩 저장 권한을 묻는다.
        // TODO: 임의 작성 문구 — 기획 확정 시 교체할 것.
        "NSPhotoLibraryAddUsageDescription": .string("촬영한 사진을 저장하려면 사진첩 접근이 필요해요.")
    ],
    usesAPIEnvironment: false, // 서버 미확정 — InMemory 저장소만 쓴다
    dependencies: [
        .homeFeature, .roomDomain,
        .roomData, // 데모앱은 조립 지점이라 Data 직접 의존 허용 (아키텍처 규칙 2의 예외)
        .composableArchitecture
    ]
)
