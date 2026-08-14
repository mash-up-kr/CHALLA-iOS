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

    /// 모듈의 유닛 테스트 타깃(<모듈명>Tests)을 생성한다.
    /// - 소스 위치는 모듈 루트의 `Tests/**` 규약 (Sources/ 옆).
    /// - 본체 타깃에 의존하므로 `@testable import <모듈명>` 가능.
    /// - 실행은 `tuist test` — 워크스페이스의 테스트 타깃을 자동 탐색해 돌린다.
    /// - Parameters:
    ///   - name: 테스트 대상 모듈 이름 (타깃 이름은 <name>Tests 로 자동 부여)
    ///   - additionalDependencies: 테스트에서만 필요한 의존.
    ///     `Tests/Support`의 목이 대상 모듈 밖 타입을 직접 import 하는 경우에 쓴다
    ///     (예: `MockHTTPClient`가 `CHALLANetwork`를 import).
    ///     이게 없으면 `Project(...)`를 손으로 구성해야 했다
    static func makeTestTarget(
        name: String,
        additionalDependencies: [TargetDependency] = []
    ) -> Target {
        return Target.target(
            name: "\(name)Tests",
            destinations: Environment.destinations,
            product: .unitTests,
            bundleId: "\(Environment.bundleIdPrefix).\(name.lowercased()).tests",
            deploymentTargets: Environment.deploymentTarget,
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [.target(name: name)] + additionalDependencies
        )
    }
}
