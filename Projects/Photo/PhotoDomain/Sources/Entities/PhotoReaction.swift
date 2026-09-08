import Foundation

/// 사진에 표시하는 리액션 한 건. 표시 ID와 삭제용 채팅 ID를 구분한다.
public struct PhotoReaction: Sendable, Hashable, Identifiable {

    public let id: String
    public let kind: ReactionKind
    public let userID: String
    /// 삭제용 서버 ID. 생성 중이거나 응답에 ID가 없으면 nil이다.
    public let chatID: Int64?

    public init(id: String, kind: ReactionKind, userID: String, chatID: Int64? = nil) {
        self.id = id
        self.kind = kind
        self.userID = userID
        self.chatID = chatID
    }

    /// 서버에서 조회한 리액션.
    public init(chatID: Int64, kind: ReactionKind, userID: String) {
        self.init(id: Self.id(forChatID: chatID), kind: kind, userID: userID, chatID: chatID)
    }

    public static func id(forChatID chatID: Int64) -> String {
        "chat-\(chatID)"
    }

    /// 표시 ID는 유지하고 삭제에 사용할 서버 ID만 채운다.
    public func attachingChatID(_ chatID: Int64) -> PhotoReaction {
        PhotoReaction(id: id, kind: kind, userID: userID, chatID: chatID)
    }
}
