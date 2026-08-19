import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "PhotoData",
    hasTests: true,
    dependencies: [.photoDomain, .network] // .network: 필터·업로드 구현이 HTTPClient로 서버를 부른다
)
