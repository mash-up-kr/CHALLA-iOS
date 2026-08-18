import ProjectDescription

public extension Settings {

    /// 모든 CHALLA 프로젝트가 공유하는 프로젝트 레벨 베이스 설정.
    ///
    /// 프로젝트 레벨에 두는 이유: 모듈 타깃뿐 아니라 같은 프로젝트의 테스트/호스트 타깃까지
    /// 한 번에 같은 Swift 언어 모드로 맞추기 위해서다 (타깃마다 중복 선언하지 않는다).
    ///
    /// Swift 언어 모드는 `Environment.swiftVersion`(6.0)으로 **고정**한다.
    ///
    /// 타입 추론 예산(탐색 횟수·기록 용량)은 기본값의 8배로 올려 둔다 — TCA 프리뷰처럼
    /// 제네릭·클로저가 겹친 식이 기본 예산(탐색 100만 회)을 넘겨 "unable to type-check this
    /// expression in reasonable time"으로 빌드가 깨진 적이 있다 (#57 CI).
    /// 이 플래그는 Swift 6.2부터 있다 — CI Xcode를 26.x로 고정하는 이유이기도 하다 (ci.yml).
    static func challaBase() -> Settings {
        .settings(base: [
            "SWIFT_VERSION": .string(Environment.swiftVersion),
            "OTHER_SWIFT_FLAGS": .array([
                "$(inherited)",
                "-Xfrontend", "-solver-scope-threshold=8388608",
                "-Xfrontend", "-solver-trail-threshold=536870912"
            ])
        ])
    }
}
