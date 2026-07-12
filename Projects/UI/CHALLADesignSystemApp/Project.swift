import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeAppProject(
    name: "CHALLADesignSystemApp",
    displayName: "CHALLA 디자인 시스템",
    bundleId: "com.challa.designsystem",
    marketingVersion: "1.0.0",
    buildNumber: "2",
    dependencies: [.designSystem]
)
