import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "SettingDomain",
    hasTests: true,
    dependencies: [.dependencies, .dependenciesMacros] // swift-dependencies (TCA 전이 의존)
)
