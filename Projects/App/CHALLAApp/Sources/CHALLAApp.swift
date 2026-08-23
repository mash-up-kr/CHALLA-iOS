import CHALLADesignSystem
import CHALLAImageKit
import ComposableArchitecture
import KakaoSDKAuth
import KakaoSDKCommon
import SwiftUI
import UIKit

/// CHALLA 앱의 진입점.
///
/// `init`의 세 줄은 순서가 강제된다 — SDK 초기화와 의존성 등록이 모두 끝난 뒤에야
/// 루트 `Store`를 만들어야 리듀서가 live 의존성을 물려받는다.
/// `prepareDependencies`가 앱 전체에서 Data 구현체를 만지는 유일한 지점이다.
@main
struct CHALLAApp: App {

    /// Firebase 초기화와 푸시 콜백 수신 (`AppDelegate` 주석 참고).
    /// 델리게이트 콜백은 이 `init`이 끝난 뒤 불리므로 그때는 의존성이 이미 등록돼 있다.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let store: StoreOf<AppFeature>

    /// 앱 전역에서 공유하는 단일 이미지 로더.
    /// 인스턴스가 분리되면 메모리 캐시와 중복 요청 관리도 함께 분리된다.
    private let imageLoader = try? ImageLoader()

    init() {
        Self.bootstrapKakaoSDK()
        // 로그아웃·탈퇴 시 이전 계정 이미지를 지우도록 같은 로더를 조립부에 넘긴다 (self 캡처 방지용 지역 바인딩).
        let loader = imageLoader
        prepareDependencies {
            CompositionRoot.registerLiveDependencies(
                into: &$0,
                clearImageCache: { await loader?.removeAll() }
            )
        }
        store = Store(initialState: .launching) {
            AppFeature()
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
                .environment(\.challaImageLoader, imageLoader)
                .task {
                    // 앱 루트 진입 시 보관 기간이 지난 디스크 캐시를 정리한다.
                    await imageLoader?.removeExpiredDiskCache()
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.didReceiveMemoryWarningNotification
                    )
                ) { _ in
                    // 메모리 압박 시 재생성 가능한 메모리 캐시만 비우고 디스크 캐시는 유지한다.
                    Task {
                        await imageLoader?.evictMemoryCache()
                    }
                }
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
