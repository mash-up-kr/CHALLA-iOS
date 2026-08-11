import ProjectDescription
import ProjectDescriptionHelpers

/// 데모앱은 앱 조립 지점이므로 예외적으로 Data(Mock/실 구현)를 주입할 수 있다 (아키텍처 규칙 2의 유일한 예외).
let project = Project.makeAppProject(
    name: "PhotoDetailFeatureDemo",
    displayName: "CHALLA PhotoDetail 데모",
    bundleId: "\(Environment.bundleIdPrefix).photodetailfeature.demo",
    marketingVersion: "1.0.0",
    buildNumber: "1",
    additionalInfoPlist: [
        // 다운로드 버튼이 사진첩 쓰기를 요청한다 — 이 값이 없으면 권한 요청 순간 앱이 죽는다.
        "NSPhotoLibraryAddUsageDescription": .string("찍은 사진을 앨범에 저장하기 위해 사용해요.")
    ],
    dependencies: [
        .photoDetailFeature,
        .photoDomain,
        .photoLibrary,
        .designSystem,
        .composableArchitecture
    ]
)
