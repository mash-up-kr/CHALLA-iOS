/// 카메라 접근 권한 창구. 구현은 `PhotoData`가 맡고 이 모듈은 OS의 존재를 모른다.
public protocol CameraPermissionProvider: Sendable {

    /// 촬영에 쓸 카메라 접근을 요청하고 허용 여부를 돌려준다.
    /// 이미 허용돼 있으면 묻지 않고 바로 true, 이전에 거절했으면 다시 묻지 못하므로 false다
    /// (iOS는 한 번 거절하면 앱이 다시 시스템 창을 띄울 수 없다 — 이후 경로는 설정 앱뿐이다).
    func requestAccess() async -> Bool

    /// 설정 앱의 이 앱 화면을 연다. 거절한 사용자가 되돌릴 수 있는 유일한 경로다.
    func openSystemSettings() async
}
