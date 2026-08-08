import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "PhotoLibrary",
    hasTests: true,
    dependencies: [.dependencies, .dependenciesMacros] // swift-dependencies (TCA 전이 의존)
)
