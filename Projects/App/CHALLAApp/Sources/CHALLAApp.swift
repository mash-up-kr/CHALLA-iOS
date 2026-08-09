import ComposableArchitecture
import KakaoSDKAuth
import KakaoSDKCommon
import SwiftUI

/// CHALLA 앱의 진입점.
///
/// `init`의 세 줄은 순서가 강제된다 — SDK 초기화와 의존성 등록이 모두 끝난 뒤에야
/// 루트 `Store`를 만들어야 리듀서가 live 의존성을 물려받는다.
/// `prepareDependencies`가 앱 전체에서 Data 구현체를 만지는 유일한 지점이다.
@main
struct CHALLAApp: App {

    private let store: StoreOf<AppFeature>

    init() {
        Self.bootstrapKakaoSDK()
        prepareDependencies { CompositionRoot.registerLiveDependencies(into: &$0) }
        store = Store(initialState: .launching) {
            AppFeature()
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
                .onOpenURL { url in
                    // 카카오톡 앱 전환 로그인에서 돌아온 URL을 SDK로 되돌려준다.
                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        _ = AuthController.handleOpenUrl(url: url)
                    }
                }
        }
    }

    /// `Configs/Shared.xcconfig`(gitignore) → Info.plist로 주입된 네이티브 앱 키로 SDK를 초기화한다.
    private static func bootstrapKakaoSDK() {
        let key = Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String ?? ""
        assert(!key.isEmpty, "KAKAO_NATIVE_APP_KEY가 비어 있음 — Configs/Shared.xcconfig 확인")
        KakaoSDK.initSDK(appKey: key)
    }
}
