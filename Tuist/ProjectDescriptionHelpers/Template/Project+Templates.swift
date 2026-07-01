import ProjectDescription

public extension Project {
    /// 프레임워크 모듈 하나를 담은 프로젝트를 생성한다.
    /// (Tuist에서 Project = 여러 타깃을 묶는 컨테이너. 여기선 타깃 1개를 담는다.)
    /// - 우리 아키텍처의 프레임워크 모듈에 사용: Feature / Domain / Data / UI(DesignSystem) / Core / Shared
    /// - 스킴은 Tuist 자동 생성(타깃당 1개)에 맡긴다 → 별도 스킴 정의 없음.
    /// - 이 프로젝트가 담는 타깃의 product(static/dynamic)는 `makeModuleTarget`이 hasResource로 자동 결정.
    /// - Parameters:
    ///   - name: 모듈 이름 (= 프로젝트/타깃 이름)
    ///   - hasResource: 리소스(폰트/애셋) 유무
    ///   - dependencies: 이 모듈(타깃)이 의존하는 대상 (호출부에서 헬퍼로 명시)
    static func makeModule(
        name: String,
        hasResource: Bool = false,
        dependencies: [TargetDependency] = []
    ) -> Project {
        return Project(
            name: name,
            organizationName: Environment.organizationName,
            options: .options(
                defaultKnownRegions: ["en", "ko"],
                developmentRegion: "ko"
            ),
            targets: [
                Target.makeModuleTarget(
                    name: name,
                    hasResource: hasResource,
                    dependencies: dependencies
                )
            ]
        )
    }
}
