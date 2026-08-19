/// 카메라 진입 안내를 이미 봤는지 기억하는 창구. 구현은 `PhotoData`가 맡는다.
///
/// 기기에만 남기고 서버에 올리지 않는다 — 기기를 바꾸면 안내를 다시 보는 편이,
/// 안내 하나 때문에 서버 왕복을 기다렸다가 화면을 늦게 그리는 것보다 낫다.
public protocol CameraOnboardingRepository: Sendable {

    /// 안내를 이미 본 적 있으면 true. 기록이 없으면 false — 즉 최초 진입이다.
    func hasSeenCoachMark() async -> Bool

    /// 안내를 끝까지 본 것으로 기록한다. 여러 번 불려도 결과는 같다.
    func markCoachMarkSeen() async
}
