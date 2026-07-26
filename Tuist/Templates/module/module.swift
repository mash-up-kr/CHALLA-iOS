import ProjectDescription

// 사용법: tuist scaffold module --name <모듈명> --group <그룹폴더>
//   예)  tuist scaffold module --name RoomDomain --group Room
//   → Projects/<그룹>/<모듈명>/{Project.swift, Sources/<모듈명>.swift, Tests/<모듈명>Tests.swift} 생성
//   (Workspace가 Projects/** 글롭이라 자동 등록됨 — 생성 후 tuist generate만 하면 워크스페이스에 뜬다)

/// 모듈 이름 (= 프로젝트/타깃/폴더 이름). 예: RoomDomain
private let nameAttribute: Template.Attribute = .required("name")

/// Projects/ 아래 그룹 폴더. 예: Room, Auth, UI, Core, Shared
private let groupAttribute: Template.Attribute = .required("group")

let moduleTemplate = Template(
    description: "CHALLA 모듈 하나(Project.swift + Sources) 생성",
    attributes: [nameAttribute, groupAttribute],
    items: [
        .file(
            path: "Projects/\(groupAttribute)/\(nameAttribute)/Project.swift",
            templatePath: "Project.stencil"
        ),
        .file(
            path: "Projects/\(groupAttribute)/\(nameAttribute)/Sources/\(nameAttribute).swift",
            templatePath: "Source.stencil"
        ),
        .file(
            path: "Projects/\(groupAttribute)/\(nameAttribute)/Tests/\(nameAttribute)Tests.swift",
            templatePath: "Tests.stencil"
        )
    ]
)
