import Foundation

/// 카메라 필터 목록과 LUT 파일을 가져오는 창구. 구현은 `PhotoData`가 맡고 이 모듈은 그 실체를 모른다.
///
/// 구현체가 지켜야 할 계약:
/// - 실패는 반드시 `PhotoError`로 번역해 던진다.
/// - LUT 파일은 만료되지 않는 공개 URL이므로 구현체가 캐시해도 된다.
public protocol CameraFilterRepository: Sendable {

    /// 서버가 제공하는 필터 전부. 화면 노출 순서 그대로 온다.
    func filters() async throws -> [CameraFilter]

    /// 필터의 LUT(.cube) 파일 원본 바이트. 파싱은 호출부 몫이다 —
    /// LUT를 CoreImage 재료로 바꾸는 일은 화면 쪽 기술이라 Domain·Data는 관여하지 않는다.
    func lutData(for filter: CameraFilter) async throws -> Data
}
