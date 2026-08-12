import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "CameraFeature",
    hasTests: true,
    dependencies: [
        .composableArchitecture,
        .designSystem
    ]
)
