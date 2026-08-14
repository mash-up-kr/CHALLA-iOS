import ProjectDescription
import ProjectDescriptionHelpers

/// .network를 testDependencies로 넘긴다 — Tests/Support의 MockHTTPClient가 CHALLANetwork를 직접 import한다.
let project = Project.makeModule(
    name: "NotificationData",
    hasTests: true,
    dependencies: [.notificationDomain, .network],
    testDependencies: [.notificationDomain, .network]
)
