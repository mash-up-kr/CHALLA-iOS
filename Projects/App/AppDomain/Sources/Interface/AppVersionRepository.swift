/// 앱 버전 정책을 서버에 묻는 인터페이스 (구현: `AppData`).
public protocol AppVersionRepository: Sendable {

    /// 현재 버전으로 계속 써도 되는지 서버에 묻는다.
    /// 실패는 정규화하지 않고 그대로 던진다 — 호출부(AppFeature)가 모든 실패를
    /// `.notRequired`로 접는 fail-open이라, 사용자에게 보일 오류 문구가 없다.
    func checkUpdateRequirement(currentVersion: String) async throws -> AppUpdateRequirement
}
