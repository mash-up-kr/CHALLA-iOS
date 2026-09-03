import Foundation
import RoomDomain

/// `InviteGuideRepository`의 기본 구현 — 안내 노출 여부를 기기에 저장한다.
public struct DefaultInviteGuideRepository: InviteGuideRepository {

    private enum Key {
        static let inviteGuideSeen = "challa.room.inviteGuide.seen"
    }

    private let storage: any InviteGuideStorage

    public init(storage: any InviteGuideStorage = UserDefaultsInviteGuideStorage()) {
        self.storage = storage
    }

    public func hasSeenInviteGuide() async -> Bool {
        storage.bool(forKey: Key.inviteGuideSeen)
    }

    public func markInviteGuideSeen() async {
        storage.setBool(true, forKey: Key.inviteGuideSeen)
    }
}
