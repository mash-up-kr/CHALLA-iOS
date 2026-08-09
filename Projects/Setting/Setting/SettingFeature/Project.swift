import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "SettingFeature",
    hasTests: true,
    dependencies: [
        .settingDomain,
        .composableArchitecture,
        .designSystem
    ]
)
