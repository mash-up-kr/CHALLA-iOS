import ProjectDescription
import ProjectDescriptionHelpers

/// 데모앱은 앱 조립 지점이므로 예외적으로 Data(Mock/실 구현)를 주입할 수 있다 (아키텍처 규칙 2의 유일한 예외).
let project = Project.makeAppProject(
    name: "ChatRoomFeatureDemo",
    displayName: "CHALLA ChatRoom 데모",
    bundleId: "\(Environment.bundleIdPrefix).chatroomfeature.demo",
    marketingVersion: "1.0.0",
    buildNumber: "1",
    dependencies: [
        .chatRoomFeature,
        .chatDomain,
        .chatData,
        .photoDomain, // ReactionKind (데모 리액션 픽스처)
        .designSystem,
        .composableArchitecture
    ]
)
