import ProjectDescription

public extension Target {
    
    /// 라이브러리/모듈 타깃을 생성한다.
    /// - product는 리소스 유무에 따라 자동 결정:
    ///   - 리소스 없음 → `.staticFramework` (앱 본체에 합쳐져 실행 빠름)
    ///   - 리소스 있음 → `.framework`(dynamic) (자기 `Bundle.module`로 리소스 접근)
    /// - bundleId는 `Environment.bundleIdPrefix` + 소문자 모듈명 규칙으로 자동 부여.
    /// - Parameters:
    ///   - name: 모듈 이름 (= 타깃 이름)
    ///   - hasResource: 리소스(폰트/애셋) 유무 → product 타입 + Resources/** 포함 여부를 함께 결정
    ///   - dependencies: 이 모듈이 의존하는 대상
    static func makeModuleTarget(
        name: String,
        hasResource: Bool = false,
        dependencies: [TargetDependency] = []
    ) -> Target {
        return Target.target(
            name: name,
            destinations: Environment.destinations,
            product: hasResource ? .framework : .staticFramework,
            bundleId: "\(Environment.bundleIdPrefix).\(name.lowercased())",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .default,
            sources: ["Sources/**"],
            resources: hasResource ? ["Resources/**"] : nil,
            dependencies: dependencies
        )
    }
}
