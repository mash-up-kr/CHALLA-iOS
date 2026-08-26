import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "ChatData",
    hasTests: true,
    dependencies: [.chatDomain, .photoDomain, .network]
)
