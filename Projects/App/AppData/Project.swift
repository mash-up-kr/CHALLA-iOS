import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "AppData",
    hasTests: true,
    dependencies: [.appDomain, .network] // .network: 버전 체크 구현이 HTTPClient로 서버를 부른다
)
