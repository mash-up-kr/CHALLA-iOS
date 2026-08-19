import ProjectDescription
import ProjectDescriptionHelpers

/// testDependencies — .networkTesting: 공용 MockHTTPClient. .network: 테스트가 NetworkError·Response를 직접 만든다.
let project = Project.makeModule(
    name: "NotificationData",
    hasTests: true,
    dependencies: [.notificationDomain, .network],
    testDependencies: [.notificationDomain, .network, .networkTesting]
)
