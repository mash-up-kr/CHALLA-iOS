import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeAppProject(
    name: "CHALLAApp",
    displayName: Environment.appName,
    bundleId: "\(Environment.bundleIdPrefix).app",   // 실배포앱 = com.challa.app
    marketingVersion: "1.0.0",
    buildNumber: "1",
    additionalInfoPlist: [
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
    entitlements: .dictionary([
        "com.apple.developer.applesignin": .array([.string("Default")])   // Sign in with Apple
    ]),
    usesAPIEnvironment: true,
    dependencies: [
        .loginFeature, .authData, .authDomain,
        .network, .keychain,
        .composableArchitecture,
        .kakaoSDKCommon, .kakaoSDKAuth      // initSDK · onOpenURL 처리용
    ]
)
