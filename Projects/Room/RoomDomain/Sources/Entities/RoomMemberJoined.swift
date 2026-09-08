import Foundation

/// 방에 새 참여자가 들어왔다는 알림.
///
/// 참여자 목록을 이 값으로 만들지는 않는다 — 목록은 이 알림을 신호 삼아 다시 조회한다.
/// 토스트 문구에 필요한 값만 담는다.
public struct RoomMemberJoined: Sendable, Equatable {

    public let roomID: Room.ID
    public let roomTitle: String
    /// 들어온 사람.
    ///
    /// optional인 것은 서버 계약이 아니라 방어다 — 이 값이 빠져도 알림 자체는 멀쩡히 쓸 수 있으므로
    /// 이벤트를 버리지 않는다. 대신 "내가 들어간 것" 판별만 못 하게 된다.
    public let userID: Int64?
    public let nickname: String
    public let profileImageURL: URL?

    public init(
        roomID: Room.ID,
        roomTitle: String,
        userID: Int64? = nil,
        nickname: String,
        profileImageURL: URL?
    ) {
        self.roomID = roomID
        self.roomTitle = roomTitle
        self.userID = userID
        self.nickname = nickname
        self.profileImageURL = profileImageURL
    }

    /// 이 알림이 나에 관한 것인지. 내가 들어간 것을 나에게 알리지 않으려고 쓴다.
    ///
    /// 닉네임은 보지 않는다 — 동명이인을 가리지 못한다.
    public func isMe(userID myUserID: Int64) -> Bool {
        userID == myUserID
    }
}

/// 참여 구독으로 흘러오는 이벤트.
public enum RoomMemberJoinedEvent: Sendable, Equatable {

    case joined(RoomMemberJoined)

    /// 끊겼다 다시 붙어 구독이 재설정됐다. 참여자 목록은 다시 조회해야 하지만
    /// 그 사이에 실제로 누가 들어왔는지는 알 수 없으므로 토스트는 띄우지 않는다.
    case resumed
}
