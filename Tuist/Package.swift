// swift-tools-version: 6.0
@preconcurrency import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    /// Xcode 27은 macOS 배포 타겟 하한이 12.0이라, 외부 패키지 기본값 11.0을 12.0으로 올린다.
    let packageSettings = PackageSettings(
        baseSettings: .settings(
            base: ["MACOSX_DEPLOYMENT_TARGET": "12.0"]
        )
    )
#endif

/// 추가·변경 후에는 `mise exec -- tuist install`을 다시 실행한다.
let package = Package(
    name: "CHALLADependencies",
    dependencies: [
        // Dependencies · DependenciesMacros는 전이 의존으로 함께 제공된다
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.26.0")),
        // KakaoSDKCommon · KakaoSDKAuth · KakaoSDKUser
        .package(url: "https://github.com/kakao/kakao-ios-sdk", .upToNextMajor(from: "2.28.0")),
        // FirebaseCore(초기화) · FirebaseMessaging(FCM 토큰) — 푸시 알림용.
        // 다른 Firebase 제품은 쓰지 않는다.
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "12.17.0"))
    ]
)
