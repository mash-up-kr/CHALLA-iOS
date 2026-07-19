import ProjectDescription
import ProjectDescriptionHelpers

// CHALLANetwork 검수앱. 대상 모듈(CHALLANetwork) 옆에 형제 앱으로 둔다.
// (디자인시스템 검수앱 CHALLADesignSystemApp과 같은 배치 전략)
let project = Project.makeAppProject(
    name: "CHALLANetworkApp",
    displayName: "CHALLA 네트워크",
    bundleId: "com.challa.networkapp",
    marketingVersion: "1.0.0",
    buildNumber: "1",
    dependencies: [.network]
)
