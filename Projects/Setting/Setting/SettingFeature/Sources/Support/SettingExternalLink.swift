import Dependencies
import DependenciesMacros
import Foundation

/// 설정 화면이 앱 밖으로 내보내는 링크.
///
/// 의존성으로 두는 이유: 테스트·데모가 주소를 갈아끼워 "어느 행이 어떤 URL을 여는가"를 확인할 수 있다.
/// `nil`이면 호출부(`SettingFeature.open(_:)`)가 아무 것도 하지 않는다.
@DependencyClient
public struct SettingExternalLinks: Sendable {

    /// 찰나 응원하기 → App Store 리뷰 작성 화면.
    /// 주소(App ID)가 확정되지 않아 행 자체를 숨겨 둔 상태다 (`SettingView.feedbackCard`).
    public var appStoreReview: @Sendable () -> URL?

    /// 피드백 보내기 → 구글폼.
    public var feedbackForm: @Sendable () -> URL?
}

extension SettingExternalLinks: DependencyKey {

    /// TODO: App ID(`https://apps.apple.com/app/id<APP_ID>?action=write-review`)가 확정되면
    /// `appStoreReview`를 채운다. 그때까지는 응원하기 행을 숨겨 두었다.
    public static let liveValue = SettingExternalLinks(
        appStoreReview: { nil },
        feedbackForm: { URL(string: "https://forms.gle/StueBwLpofWJ21dG9") }
    )

    public static let testValue = SettingExternalLinks()
}

public extension DependencyValues {
    var settingExternalLinks: SettingExternalLinks {
        get { self[SettingExternalLinks.self] }
        set { self[SettingExternalLinks.self] = newValue }
    }
}
