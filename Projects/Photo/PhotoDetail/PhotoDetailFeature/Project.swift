import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "PhotoDetailFeature",
    hasTests: true,
    dependencies: [
        .photoDomain,
        .composableArchitecture,
        .designSystem
    ]
)
