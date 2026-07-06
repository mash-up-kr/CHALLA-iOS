import ProjectDescription

let workspace = Workspace(
    name: "CHALLA",
    projects: [
        // Projects/ 아래 모든 모듈을 자동 포함 (scaffold로 새 모듈 추가 시 수동 등록 불필요)
        "Projects/**"
    ]
)
