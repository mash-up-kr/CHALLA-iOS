import ProjectDescription
import ProjectDescriptionHelpers

/// 서버가 주는 커버 값(색 hex · 스티커 SVG)을 화면에 올리는 매핑·뷰. 홈과 방 상세가 함께 쓴다 —
/// Feature끼리 import 할 수 없어 따로 뗀 모듈이다 (ShootEntry와 같은 위치).
let project = Project.makeModule(
    name: "RoomCoverUI",
    hasTests: true,
    // .imageKit: 스티커 SVG를 도형으로 받아 오는 로더 (뷰가 URLSession을 직접 부르지 않는다)
    dependencies: [.roomDomain, .designSystem, .imageKit],
    testDependencies: [.roomDomain, .designSystem, .imageKit]
)
