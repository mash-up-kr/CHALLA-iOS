import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "PhotoData",
    hasTests: true,
    // .network: 필터·업로드 구현이 HTTPClient로 서버를 부른다
    // .imageKit: 업로더가 촬영본을 서버 상한(5MB) 이하로 압축한다
    dependencies: [.photoDomain, .network, .imageKit]
)
