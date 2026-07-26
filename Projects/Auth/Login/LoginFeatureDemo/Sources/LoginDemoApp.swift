import SwiftUI
import KakaoSDKCommon
import KakaoSDKAuth

/// LoginFeature 데모앱 진입점.
/// 카카오 SDK 초기화와 로그인 콜백 URL 처리는 앱 조립 지점의 책임이다.
@main
struct LoginDemoApp: App {

    init() {
        // 네이티브 앱 키는 xcconfig → Info.plist로 주입된다 (저장소에 키를 커밋하지 않기 위함).
        let key = Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String ?? ""
        // 비어 있으면 로그인 시점에야 모호한 SDK 오류가 나므로 여기서 조기에 알린다.
        assert(!key.isEmpty, "KAKAO_NATIVE_APP_KEY가 비어 있음 — Configs/Shared.xcconfig 확인")
        KakaoSDK.initSDK(appKey: key)
    }

    var body: some Scene {
        WindowGroup {
            DemoRootView()
                .onOpenURL { url in
                    // 카카오톡 앱 로그인에서 돌아오는 kakao{키}:// 콜백 처리
                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        _ = AuthController.handleOpenUrl(url: url)
                    }
                }
        }
    }
}
