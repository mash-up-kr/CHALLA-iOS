// swift-tools-version: 6.0
@preconcurrency import PackageDescription

/// 추가·변경 후에는 `mise exec -- tuist install`을 다시 실행한다.
let package = Package(
    name: "CHALLADependencies",
    dependencies: [
        // Dependencies · DependenciesMacros는 전이 의존으로 함께 제공된다
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.26.0")),
        // KakaoSDKCommon · KakaoSDKAuth · KakaoSDKUser
        .package(url: "https://github.com/kakao/kakao-ios-sdk", .upToNextMajor(from: "2.28.0"))
    ]
)
