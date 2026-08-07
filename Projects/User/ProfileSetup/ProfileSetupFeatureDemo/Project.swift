import ProjectDescription
import ProjectDescriptionHelpers

/// 데모앱은 앱 조립 지점이므로 예외적으로 Data(Mock/실 구현)를 주입할 수 있다 (아키텍처 규칙 2의 유일한 예외).
let project = Project.makeAppProject(
    name: "ProfileSetupFeatureDemo",
    displayName: "CHALLA ProfileSetup 데모",
    bundleId: "\(Environment.bundleIdPrefix).profilesetupfeature.demo",
    marketingVersion: "1.0.0",
    buildNumber: "1",
    additionalInfoPlist: [
        // TODO: 문구는 기획 미확정 — 확정 시 교체할 것 (App Store 심사 대상 문구).
        "NSPhotoLibraryUsageDescription": .string("프로필 사진을 설정하려면 사진 접근이 필요해요.")
    ],
    dependencies: [
        .profileSetupFeature, .userDomain, .photoLibrary,
        .composableArchitecture,
        .designSystem // 진입점의 CHALLAFontRegister.register() 호출용 — 미호출 시 타이포 검증이 전부 DIFF
    ]
)
