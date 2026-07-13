import ProjectDescription

/// 프로젝트 전역 상수
/// 배포 타겟·번들ID 접두사 등
public enum Environment {

    public static let appName: String = "CHALLA"
    public static let organizationName: String = "CHALLA"
    public static let bundleIdPrefix: String = "com.challa"
    public static let destinations: Destinations = [.iPhone]
    public static let deploymentTarget: DeploymentTargets = .iOS("17.0")
}
