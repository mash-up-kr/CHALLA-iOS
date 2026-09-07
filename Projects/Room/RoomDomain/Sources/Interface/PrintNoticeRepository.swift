/// 인화 완료 안내를 이미 봤는지 방마다 기억하는 창구. 구현은 `RoomData`가 맡는다.
///
/// 서버가 아니라 기기에 저장한다. 안내 하나 때문에 화면을 늦게 그리지 않기 위해서다 —
/// 대신 기기를 바꾸면 다시 보인다.
public protocol PrintNoticeRepository: Sendable {

    /// 본 적 있으면 true. 기록이 없으면 false — 인화 완료 후 첫 진입이다.
    func hasSeenPrintNotice(roomID: Room.ID) async -> Bool

    /// 이 방의 안내를 본 것으로 기록한다. 여러 번 불려도 결과는 같다.
    func markPrintNoticeSeen(roomID: Room.ID) async
}
