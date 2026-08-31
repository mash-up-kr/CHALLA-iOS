import Foundation

/// 서버가 내린 업데이트 요구 수준.
///
/// `recommended`(권장 업데이트)는 일부러 넣지 않았다 — 시안도 정책도 없어서 지금 만들면 죽은 코드가 된다.
/// (서버 응답의 `updateAvailable`·`latestVersion`이 그 재료다 — 정책이 생기면 여기부터 확장한다.)
public enum AppUpdateRequirement: Equatable, Sendable {
    case notRequired
    /// 업데이트해야만 앱을 쓸 수 있다. `storeURL`은 서버가 준 스토어 주소 —
    /// 형식이 깨져 있으면 nil이고, 호출부는 아무 것도 열지 않는다.
    case forced(storeURL: URL?)
}
