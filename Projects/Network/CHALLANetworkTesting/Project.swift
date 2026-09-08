import ProjectDescription
import ProjectDescriptionHelpers

/// 테스트 전용 지원 모듈 — 각 Data 모듈 테스트가 공유하는 `MockHTTPClient`를 담는다.
/// 테스트 타깃만 의존하므로 앱 번들에는 포함되지 않는다.
let project = Project.makeModule(
    name: "CHALLANetworkTesting",
    dependencies: [.network]
)
