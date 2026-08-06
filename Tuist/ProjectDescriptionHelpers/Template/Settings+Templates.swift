import ProjectDescription

public extension Settings {

    /// 모든 CHALLA 프로젝트가 공유하는 프로젝트 레벨 베이스 설정.
    ///
    /// 프로젝트 레벨에 두는 이유: 모듈 타깃뿐 아니라 같은 프로젝트의 테스트/호스트 타깃까지
    /// 한 번에 같은 Swift 언어 모드로 맞추기 위해서다 (타깃마다 중복 선언하지 않는다).
    ///
    /// Swift 언어 모드는 `Environment.swiftVersion`(6.0)으로 **고정**한다.
    static func challaBase() -> Settings {
        .settings(base: ["SWIFT_VERSION": .string(Environment.swiftVersion)])
    }
}
