import Foundation
import PhotoDomain

/// 채팅 메시지 식별자.
///
/// 서버가 주는 `chatId`를 쓴다. 아직 전송 응답을 못 받은 낙관적 메시지만 로컬 id를 갖고,
/// 전송이 성공하면 서버 id로 바뀐다(`ChatMessage.promoted(toServerID:)`).
/// 이 구분이 있어야 소켓으로 되돌아온 내 메시지가 목록에 두 번 뜨지 않는다.
///
/// `ChatMessage.ID`로도 쓸 수 있다 — `Identifiable`이 이 타입을 그 이름으로 이어 준다.
public enum ChatMessageID: Hashable, Sendable {
    case server(Int64)
    case local(UUID)
}

/// 채팅 한 건. 텍스트 · 사진(+메시지) · 사진에 달린 이모지 리액션 중 하나다 — 반응/채팅 하나당 한 아이템.
public struct ChatMessage: Identifiable, Sendable, Equatable {

    public enum Kind: Sendable, Equatable {
        /// 텍스트 메시지.
        case text
        /// 사진 메시지. `content`가 있으면 사진과 함께 메시지도 보여준다.
        case photo
        /// 사진에 달린 이모지 리액션. 사진 위에 그 이모지를 얹어 보여준다.
        case reaction(ReactionKind)
    }

    public let id: ChatMessageID
    public let kind: Kind
    /// 텍스트 본문. 사진·이모지 메시지는 비어 있을 수 있다.
    public let content: String
    /// 사진 메시지·이모지 리액션이 가리키는 이미지 주소. 순수 텍스트는 nil.
    public let photoImageURL: URL?
    /// 보낸 사람(응답의 `userId`). 내 메시지 판별 기준이다.
    public let authorID: Int64
    /// 보낸 사람 표시 이름(응답의 `userName`).
    public let authorName: String
    public let authorImageURL: URL?
    public let createdAt: Date

    public init(
        id: ChatMessageID,
        kind: Kind,
        content: String = "",
        photoImageURL: URL? = nil,
        authorID: Int64,
        authorName: String,
        authorImageURL: URL? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.content = content
        self.photoImageURL = photoImageURL
        self.authorID = authorID
        self.authorName = authorName
        self.authorImageURL = authorImageURL
        self.createdAt = createdAt
    }

    /// 이 메시지가 내 것인지 — 오른쪽 정렬·흰 버블 판별용.
    public func isMine(currentUserID: Int64) -> Bool {
        authorID == currentUserID
    }

    /// 전송 응답으로 받은 서버 id를 붙여 확정한다.
    /// 이후 소켓으로 같은 메시지가 되돌아와도 id가 같아 목록에서 한 건으로 합쳐진다.
    public func promoted(toServerID chatID: Int64) -> ChatMessage {
        ChatMessage(
            id: .server(chatID),
            kind: kind,
            content: content,
            photoImageURL: photoImageURL,
            authorID: authorID,
            authorName: authorName,
            authorImageURL: authorImageURL,
            createdAt: createdAt
        )
    }
}
