import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: "SettingData",
    hasTests: true,
    // 네트워크 의존이 없다 — 테마·알림은 로컬 저장이고, 프로필 조회는 이슈 #33의 UserRepository 몫이다.
    // (자세한 배경은 MODULE.md "프로필은 왜 여기 없나" 참고)
    dependencies: [.settingDomain]
)
