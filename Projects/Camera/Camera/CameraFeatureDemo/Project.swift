import ProjectDescription
import ProjectDescriptionHelpers

/// 데모앱은 앱 조립 지점이므로 예외적으로 Data(Mock/실 구현)를 주입할 수 있다 (아키텍처 규칙 2의 유일한 예외).
/// 로그인이 없어 실서버 대신 InMemory 구현을 꽂는다 — 필터 LUT는 코드 생성 목 데이터가 서버 파일을 대신한다.
let project = Project.makeAppProject(
    name: "CameraFeatureDemo",
    displayName: "CHALLA Camera 데모",
    bundleId: "\(Environment.bundleIdPrefix).camerafeature.demo",
    marketingVersion: "1.0.0",
    buildNumber: "1",
    additionalInfoPlist: [
        // TODO: 문구는 기획 미확정 — 확정 시 교체할 것 (App Store 심사 대상 문구).
        "NSCameraUsageDescription": .string("카메라로 사진을 촬영하려면 카메라 접근이 필요해요."),
        "NSPhotoLibraryAddUsageDescription": .string("촬영한 사진을 저장하려면 사진첩 접근이 필요해요.")
    ],
    dependencies: [
        .cameraFeature,
        .roomDomain, .roomData,
        .photoDomain, .photoData,
        .composableArchitecture
    ]
)
