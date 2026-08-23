import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "ChatRoomFeature",
    hasTests: true,
    dependencies: [
        .chatDomain,
        .photoDomain, // ReactionKind + 이모지 스티커 매핑(사진에 달린 리액션 렌더)
        .composableArchitecture,
        .designSystem
    ]
)
