import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "PhotoData",
    hasTests: true,
    // .network: 필터·업로드 구현이 HTTPClient로 서버를 부른다
    dependencies: [.photoDomain, .network],
    // .networkTesting: 공용 MockHTTPClient (테스트가 CHALLANetwork 타입도 직접 쓴다)
    testDependencies: [.networkTesting]
)
