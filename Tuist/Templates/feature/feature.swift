import ProjectDescription

// 사용법: tuist scaffold feature --name <피처명> --group <그룹폴더>
//   예)  tuist scaffold feature --name Login --group Auth
//        → Projects/Auth/Login/{LoginFeature, LoginFeatureDemo}
//   피처가 아닌 모듈(Domain·Data·Core·Shared)은 tuist scaffold module 을 쓴다.

/// 피처 이름 — "Feature" 접미사 없이 넘긴다. 예: Login → LoginFeature · LoginFeatureDemo
private let nameAttribute: Template.Attribute = .required("name")

/// Projects/ 아래 그룹 폴더. 예: Auth, Room, Home
private let groupAttribute: Template.Attribute = .required("group")

let featureTemplate = Template(
    description: "CHALLA 피처 한 세트(<피처명>/ 아래 피처 모듈 + 데모앱) 생성",
    attributes: [nameAttribute, groupAttribute],
    items: [
        .file(
            path: "Projects/\(groupAttribute)/\(nameAttribute)/\(nameAttribute)Feature/Project.swift",
            templatePath: "Project.stencil"
        ),
        .file(
            path: "Projects/\(groupAttribute)/\(nameAttribute)/\(nameAttribute)Feature/Sources/\(nameAttribute)Feature.swift",
            templatePath: "Source.stencil"
        ),
        // 데모앱 스텐실은 demo 템플릿과 공유한다 (한쪽만 고치는 드리프트 방지).
        .file(
            path: "Projects/\(groupAttribute)/\(nameAttribute)/\(nameAttribute)FeatureDemo/Project.swift",
            templatePath: "../demo/Project.stencil"
        ),
        .file(
            path: "Projects/\(groupAttribute)/\(nameAttribute)/\(nameAttribute)FeatureDemo/Sources/\(nameAttribute)DemoApp.swift",
            templatePath: "../demo/App.stencil"
        ),
        .file(
            path: "Projects/\(groupAttribute)/\(nameAttribute)/\(nameAttribute)FeatureDemo/Resources/Assets.xcassets/Contents.json",
            templatePath: "../demo/Assets.stencil"
        )
    ]
)
