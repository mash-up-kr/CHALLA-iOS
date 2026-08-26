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
        "NSCameraUsageDescription": .string("사진을 촬영하려면 카메라 접근이 필요해요."),
        "NSPhotoLibraryAddUsageDescription": .string("촬영한 사진을 저장하려면 사진첩 접근이 필요해요."),
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
    entitlements: .file(path: "CHALLAApp.entitlements"), // Sign in with Apple + 푸시(development)
    // 배포 빌드는 aps-environment가 production이어야 한다 — App Store 프로파일이 development를
    // 포함하지 않아 서명이 거부되기 때문. 두 파일은 이 항목만 다르므로 함께 관리할 것.
    releaseEntitlements: .file(path: "CHALLAApp.Release.entitlements"),
    hasTests: true, // AppFeature의 화면 전이가 검증 대상이다
    signing: .manual(
        debugProfile: "CHALLA_iOS_Development_2026",
        releaseProfile: "CHALLA_iOS_AppStore_2026"
    ),
    usesAPIEnvironment: true,
    dependencies: [
        .loginFeature, .authData, .authDomain,
        .profileSetupFeature, .userData, .userDomain,
        .settingFeature, .settingData, .settingDomain,
        .notificationData, .notificationDomain,
        .homeFeature, .roomDetailFeature, .roomData, .roomDomain,
        .cameraFeature, .cameraSession, .shootEntry, .photoData, .photoDomain,
        .photoDetailFeature, .photoLibrary,
        .chatRoomFeature, .chatData, .chatDomain,
        .network, .keychain,
        .designSystem, .imageKit,
        .composableArchitecture,
        .kakaoSDKCommon, .kakaoSDKAuth, // initSDK · onOpenURL 처리용
        .firebaseCore, .firebaseMessaging // FirebaseApp.configure · FCM 토큰
    ]
)
