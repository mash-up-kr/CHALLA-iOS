import ProjectDescription
import ProjectDescriptionHelpers

/// hasTests를 켜지 않는다 — 이 모듈은 프로토콜과 오류 enum뿐이라 검증할 로직이 없다.
/// 서버 계약과 오류 정규화는 NotificationData의 테스트가 고정한다 (MODULE.md 참고).
let project = Project.makeModule(name: "NotificationDomain")
