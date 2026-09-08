import Foundation
import RoomDomain

/// `PrintNoticeRepository`의 기본 구현 — 안내 노출 여부를 방마다 기기에 저장한다.
public struct DefaultPrintNoticeRepository: PrintNoticeRepository {

    /// 방마다 키를 하나씩 쓴다. 하나의 키에 방 목록을 모아 두면 읽고 쓸 때마다
    /// 목록 전체를 갈아 끼워야 해서, 값이 Bool 하나뿐인 기록에는 과하다.
    /// 방은 30일 뒤 서버가 지우지만 이 기록은 남는다 — 키 하나가 Bool 하나라 무시할 수 있는 크기다.
    private static func key(roomID: Room.ID) -> String {
        "challa.room.printNotice.seen.\(roomID)"
    }

    private let storage: any PrintNoticeStorage

    public init(storage: any PrintNoticeStorage = UserDefaultsPrintNoticeStorage()) {
        self.storage = storage
    }

    public func hasSeenPrintNotice(roomID: Room.ID) async -> Bool {
        storage.bool(forKey: Self.key(roomID: roomID))
    }

    public func markPrintNoticeSeen(roomID: Room.ID) async {
        storage.setBool(true, forKey: Self.key(roomID: roomID))
    }
}
