import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeAppProject(
    name: "CHALLADesignSystemApp",
    displayName: "CHALLA 디자인 시스템",
    bundleId: "com.challa.designsystem",
    dependencies: [.designSystem]
)
