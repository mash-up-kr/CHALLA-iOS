import Dependencies
import DependenciesMacros
import Foundation

/// 서버가 내린 업데이트 요구 수준.
///
/// `recommended`(권장 업데이트)는 일부러 넣지 않았다 — 시안도 정책도 없어서 지금 만들면 죽은 코드가 된다.
public enum AppUpdateRequirement: Equatable, Sendable {
    case notRequired
    case forced
}

/// 앱 실행 직후 버전 체크와, 강제 업데이트 시 보낼 스토어 주소.
///
/// TODO: 버전 체크 API 스펙이 확정되면 `AppDomain`(UseCase) + `AppData`(Repository)로 옮기고
///       `CompositionRoot`에서 배선한다. 지금은 조립할 Data 구현이 없어 App 모듈에 임시로 둔다.
@DependencyClient
struct AppUpdateClient: Sendable {

    /// 실행 직후 1회 호출. 실패는 그대로 던진다 — fail-open 정책은 `AppFeature`가 소유한다.
    var checkRequirement: @Sendable () async throws -> AppUpdateRequirement

    /// 강제 업데이트 알럿의 '확인'이 열 주소. `nil`이면 호출부가 아무 것도 하지 않는다
    /// (`SettingExternalLinks`와 같은 규약).
    var appStoreURL: @Sendable () -> URL? = { nil }
}

extension AppUpdateClient: DependencyKey {

    /// TODO: 버전 체크 API 미연동 — 항상 통과시킨다. 서버 연동 시 이 자리를 실제 호출로 교체할 것.
    ///       연동 담당 필수: 요청 타임아웃을 짧게(3초 내외) 잡을 것. 길면 스플래시가 그만큼 멈춘다.
    /// TODO: App Store 미등록 — id는 존재하지 않는 임시값이다. 등록 후 실제 App ID로 교체할 것.
    static let liveValue = AppUpdateClient(
        checkRequirement: { .notRequired },
        appStoreURL: { URL(string: "https://apps.apple.com/kr/app/id0000000000") }
    )

    static let testValue = AppUpdateClient()
}

extension DependencyValues {
    var appUpdateClient: AppUpdateClient {
        get { self[AppUpdateClient.self] }
        set { self[AppUpdateClient.self] = newValue }
    }
}
