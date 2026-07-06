import ProjectDescription

/// 모듈 의존성을 짧고 안전하게 선언하기 위한 헬퍼.
/// 각 Project.swift는 `.project(target:path:)`를 길게 쓰는 대신 여기 정의된 값을 쓴다.
/// (새 모듈이 생기면 여기에 case/프로퍼티를 추가해 나간다.)
public extension TargetDependency {

    // MARK: - UI
    /// CHALLADesignSystem 모듈에 대한 의존성.
    /// 이 모듈(디자인시스템)을 가져다 쓰는 앱/피처의 `dependencies`에 `.designSystem`으로 추가한다.
    static let designSystem = TargetDependency.project(
        target: "CHALLADesignSystem",
        path: .relativeToRoot("Projects/UI/CHALLADesignSystem")
    )
}
