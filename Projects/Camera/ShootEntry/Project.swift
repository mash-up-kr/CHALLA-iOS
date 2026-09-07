import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "ShootEntry",
    hasTests: true,
    // .composableArchitecture: 실패 얼럿(AlertState)을 여기서 만들어 두 피처가 같은 문구를 쓴다.
    dependencies: [.roomDomain, .photoDomain, .photoLibrary, .composableArchitecture],
    testDependencies: [.roomDomain, .photoDomain, .photoLibrary, .composableArchitecture]
)
