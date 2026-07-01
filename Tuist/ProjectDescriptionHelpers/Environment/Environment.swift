import ProjectDescription

/// 프로젝트 전역 상수
/// 배포 타겟·번들ID 접두사 등을 바꿀 일이 있으면 여기 한 곳만 고친다.
public enum Environment {
    /// 서비스 이름
    public static let appName: String = "CHALLA"
    /// 조직 이름 (Xcode organizationName)
    public static let organizationName: String = "CHALLA"
    /// 번들 ID 접두사 
    public static let bundleIdPrefix: String = "com.challa"
    /// 지원 플랫폼 (iPhone 전용)
    public static let destinations: Destinations = [.iPhone]
    /// 최소 지원 버전
    public static let deploymentTarget: DeploymentTargets = .iOS("17.0")
}
