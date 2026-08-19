import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "PhotoDomain",
    hasTests: true,
    dependencies: [.dependencies, .dependenciesMacros] // swift-dependencies (TCA 전이 의존, @DependencyClient 매크로)
)
