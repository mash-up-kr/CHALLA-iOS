import Foundation
import RoomDomain

/// 데모·테스트용 가짜 안내 기록소. 앱을 끄면 사라져 매번 안내부터 다시 볼 수 있다.
public actor InMemoryPrintNoticeRepository: PrintNoticeRepository {

    private var seenRoomIDs: Set<Room.ID>

    public init(seenRoomIDs: Set<Room.ID> = []) {
        self.seenRoomIDs = seenRoomIDs
    }

    public func hasSeenPrintNotice(roomID: Room.ID) async -> Bool {
        seenRoomIDs.contains(roomID)
    }

    public func markPrintNoticeSeen(roomID: Room.ID) async {
        seenRoomIDs.insert(roomID)
    }
}
