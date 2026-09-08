import ProjectDescription
import ProjectDescriptionHelpers

/// 유닛테스트를 두지 않는다 — 실기기 카메라·사진첩이 있어야 의미 있는 코드라 시뮬레이터 테스트로 검증되지 않는다.
let project = Project.makeModule(
    name: "CameraSession",
    hasTests: false,
    dependencies: [.cameraFeature, .photoDomain, .composableArchitecture]
)
