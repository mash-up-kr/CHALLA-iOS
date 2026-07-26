import ProjectDescription
import ProjectDescriptionHelpers

// LoginFeature 피처 데모앱.
// 데모앱은 앱 조립 지점이므로 예외적으로 AuthData(실 구현)를 주입할 수 있다 (아키텍처 규칙 2의 유일한 예외).
// - 카카오 네이티브 앱 키는 Configs/Shared.xcconfig(gitignore)에서 $(KAKAO_NATIVE_APP_KEY)로 주입된다.
// - 백엔드 서버 값(baseURL·ATS 예외)은 usesAPIEnvironment가 Configs/Shared.xcconfig 기준으로 자동 주입한다.
let project = Project.makeAppProject(
    name: "LoginFeatureDemo",
    displayName: "CHALLA 로그인 데모",
    bundleId: "\(Environment.bundleIdPrefix).loginfeature.demo",
    marketingVersion: "1.0.0",
    buildNumber: "1",
    additionalInfoPlist: [
        // 카카오 SDK — 네이티브 앱 키 + 카카오톡 앱 전환 스킴
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
        // 합성 루트(임시)가 구체 어댑터를 직접 조립하므로 Network·Keychain을 직접 의존한다.
        // TODO: [App/DIContainer 도입 시 이관] 조립이 DIContainer로 옮겨가면 이 두 의존성은 그쪽으로 이동한다.
        .network, .keychain,
        .composableArchitecture,
        .kakaoSDKCommon, .kakaoSDKAuth      // 조립 지점의 initSDK · onOpenURL 처리용
    ]
)
