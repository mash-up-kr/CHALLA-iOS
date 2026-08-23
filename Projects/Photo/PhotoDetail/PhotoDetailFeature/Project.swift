import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "PhotoDetailFeature",
    hasTests: true,
    dependencies: [
        .photoDomain,
        .chatDomain, // 사진 상세에서 채팅 메시지 전송(SendChatUseCase)
        .composableArchitecture,
        .designSystem
    ]
)
