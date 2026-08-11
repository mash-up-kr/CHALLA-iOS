import ProjectDescription
import ProjectDescriptionHelpers

/// 테스트 타깃을 두지 않는다 — 이 모듈의 코드는 전부 사진첩 권한 팝업과 시스템 사진첩 상태에
/// 의존해서 유닛테스트로 고정할 만한 순수 로직이 없다. 동작 확인은 데모앱 실행으로 한다.
let project = Project.makeModule(name: "PhotoLibrary") // 외부 의존 0 (Photos는 시스템)
