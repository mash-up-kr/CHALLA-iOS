import ProjectDescription
import ProjectDescriptionHelpers

/// 데모앱은 앱 조립 지점이므로 예외적으로 Data(Mock/실 구현)를 주입할 수 있다 (아키텍처 규칙 2의 유일한 예외).
/// 카메라는 서버 연동 전이라 아직 Data가 없다 — 방·필터·촬영 가능 여부를 Mock State로 직접 주입한다.
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
        .composableArchitecture
    ]
)
