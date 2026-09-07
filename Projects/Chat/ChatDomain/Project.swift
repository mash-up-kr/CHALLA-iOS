import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "ChatDomain",
    hasTests: true,
    dependencies: [.photoDomain, .dependencies, .dependenciesMacros]
)
