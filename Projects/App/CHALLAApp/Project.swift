import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeAppProject(
    name: "CHALLAApp",
    displayName: Environment.appName,
    bundleId: "\(Environment.bundleIdPrefix).app", // 실배포앱 = com.challa.app
    marketingVersion: "1.0.0",
    buildNumber: "1",
    additionalInfoPlist: [
        // TODO: 임의 작성 문구 — 기획 확정 시 교체할 것. (없으면 권한 요청 시점에 앱이 크래시한다)
        "NSPhotoLibraryUsageDescription": .string("프로필 사진을 설정하려면 사진 접근이 필요해요."),
        "KAKAO_NATIVE_APP_KEY": .string("$(KAKAO_NATIVE_APP_KEY)"),
        "LSApplicationQueriesSchemes": .array([
            .string("kakaokompassauth"), .string("kakaolink")
        ]),
        "CFBundleURLTypes": .array([
            .dictionary([
                "CFBundleTypeRole": .string("Editor"),
                "CFBundleURLSchemes": .array([.string("kakao$(KAKAO_NATIVE_APP_KEY)")])
            ])
        ])
    ],
    // 실제 파일로 둔다(.dictionary가 아니라) — dictionary면 generate마다 Derived에 다시 쓰여서,
    // Xcode 빌드 중에 generate가 돌면 "Entitlements file was modified during the build"로 실패한다.
    entitlements: .file(path: "CHALLAApp.entitlements"), // Sign in with Apple
    usesAPIEnvironment: true,
    dependencies: [
        .loginFeature, .authData, .authDomain,
        .profileSetupFeature, .userData, .userDomain,
        .network, .keychain,
        .designSystem, .imageKit,
        .composableArchitecture,
        .kakaoSDKCommon, .kakaoSDKAuth // initSDK · onOpenURL 처리용
    ]
)
