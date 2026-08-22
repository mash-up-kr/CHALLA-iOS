import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "AppDomain",
    hasTests: true,
    dependencies: [.dependencies, .dependenciesMacros] // swift-dependencies (@DependencyClient 매크로)
)
