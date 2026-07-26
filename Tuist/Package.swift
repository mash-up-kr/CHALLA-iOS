// swift-tools-version: 6.0
@preconcurrency import PackageDescription

#if TUIST
import struct ProjectDescription.PackageSettings

let packageSettings = PackageSettings(
    // 전부 static(기본값)으로 둔다. TCA를 dynamic으로 승격하면 전이 의존(swift-dependencies)이
    // TCA dylib과 앱 바이너리에 각각 복제 링크되어 DependencyValues의 TaskLocal 전역이 이미지별로 갈라지고,
    // withDependencies 주입이 리듀서의 @Dependency에 보이지 않게 된다 (Mock 로그인 실패 버그).
    productTypes: [:],
    baseSettings: .settings(base: [
        // Xcode 26 Explicitly Built Modules가 매크로 지원 모듈(CasePathsMacrosSupport 등)의
        // modulemap 스캔에서 아직 생성 전인 -Swift.h를 찾다 실패하는 이슈 워크어라운드.
        // Xcode GUI 빌드는 통과하고 xcodebuild/CI만 실패한다. Xcode가 고쳐지면 제거.
        "SWIFT_ENABLE_EXPLICIT_MODULES": "NO",
        "CLANG_ENABLE_EXPLICIT_MODULES": "NO"
    ])
)
#endif

// 추가·변경 후에는 `mise exec -- tuist install`을 다시 실행한다.
let package = Package(
    name: "CHALLADependencies",
    dependencies: [
        // Dependencies · DependenciesMacros는 전이 의존으로 함께 제공된다
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.26.0")),
        // KakaoSDKCommon · KakaoSDKAuth · KakaoSDKUser
        .package(url: "https://github.com/kakao/kakao-ios-sdk", .upToNextMajor(from: "2.28.0"))
    ]
)
