import ProjectDescription

// 사용법: tuist scaffold demo --name <피처명> --group <그룹폴더>
//   예)  tuist scaffold demo --name Room --group Room
//        → Projects/Room/Room/RoomFeatureDemo (기존 RoomFeature와 형제)
//   이미 있는 피처에 데모앱만 뒤늦게 붙일 때 쓴다. 새 피처는 tuist scaffold feature 로 한 번에 만든다.

/// 피처 이름 — "Feature" 접미사 없이 넘긴다. 예: Login → LoginFeatureDemo
private let nameAttribute: Template.Attribute = .required("name")

/// Projects/ 아래 그룹 폴더. 예: Auth, Room, Home
private let groupAttribute: Template.Attribute = .required("group")

let demoTemplate = Template(
    description: "CHALLA 피처 데모앱 하나(Project.swift + Sources) 생성 — 피처 모듈과 같은 <피처명> 폴더 안 형제 위치",
    attributes: [nameAttribute, groupAttribute],
    items: [
        .file(
            path: "Projects/\(groupAttribute)/\(nameAttribute)/\(nameAttribute)FeatureDemo/Project.swift",
            templatePath: "Project.stencil"
        ),
        .file(
            path: "Projects/\(groupAttribute)/\(nameAttribute)/\(nameAttribute)FeatureDemo/Sources/\(nameAttribute)DemoApp.swift",
            templatePath: "App.stencil"
        ),
        .file(
            path: "Projects/\(groupAttribute)/\(nameAttribute)/\(nameAttribute)FeatureDemo/Resources/Assets.xcassets/Contents.json",
            templatePath: "Assets.stencil"
        )
    ]
)
