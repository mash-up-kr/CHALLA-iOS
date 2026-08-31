import Foundation

/// `GET /api/v1/app/version` 응답의 `data` — `{ app: { ... } }` 이중 껍데기 (스웨거 그대로).
struct AppVersionResponseDTO: Decodable, Sendable {
    let app: AppVersionDTO
}

struct AppVersionDTO: Decodable, Sendable {
    let updateRequired: Bool
    /// 최신 버전이 있다는 표시일 뿐 강제는 아니다 — 권장 업데이트 정책이 없어 아직 안 쓴다
    /// (`AppUpdateRequirement` 주석 참고).
    let updateAvailable: Bool
    let latestVersion: String
    let storeUrl: String
}
