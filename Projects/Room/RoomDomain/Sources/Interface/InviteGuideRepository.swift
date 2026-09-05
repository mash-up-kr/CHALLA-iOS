/// 초대 안내(팝오버 자동 열림 + 툴팁)를 이미 봤는지 기억하는 창구. 구현은 `RoomData`가 맡는다.
/// 기록은 기기에만 남고 서버에 올리지 않는다 — 기기를 바꾸면 안내가 한 번 더 뜬다.
public protocol InviteGuideRepository: Sendable {

    /// 안내를 이미 본 적 있으면 true. 기록이 없으면 false — 즉 최초 진입이다.
    func hasSeenInviteGuide() async -> Bool

    /// 안내를 본 것으로 기록한다. 여러 번 불려도 결과는 같다.
    func markInviteGuideSeen() async
}
