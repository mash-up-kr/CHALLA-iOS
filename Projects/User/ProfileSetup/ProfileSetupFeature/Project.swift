import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "ProfileSetupFeature",
    hasTests: true,
    dependencies: [
        .userDomain,
        .photoLibrary,
        .composableArchitecture,
        .designSystem
    ]
)
