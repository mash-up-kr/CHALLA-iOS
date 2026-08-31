import Foundation
import PhotoDomain

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

    /// 서버가 메시지 id를 주지 않아 매핑/전송 시점에 생성한다(목록 렌더용 안정 키).
    public let id: UUID
    public let kind: Kind
    /// 텍스트 본문. 사진·이모지 메시지는 비어 있을 수 있다.
    public let content: String
    /// 사진 메시지·이모지 리액션이 가리키는 이미지 주소. 순수 텍스트는 nil.
    public let photoImageURL: URL?
    /// 보낸 사람 표시 이름(응답의 `userName`). 서버가 userId를 주지 않아 화면이 이 값으로 내 메시지를 판별한다.
    public let authorName: String
    public let authorImageURL: URL?
    public let createdAt: Date

    public init(
        id: UUID,
        kind: Kind,
        content: String = "",
        photoImageURL: URL? = nil,
        authorName: String,
        authorImageURL: URL? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.content = content
        self.photoImageURL = photoImageURL
        self.authorName = authorName
        self.authorImageURL = authorImageURL
        self.createdAt = createdAt
    }

    /// 이 메시지가 주어진 사용자(닉네임)의 것인지 — 오른쪽 정렬·흰 버블 판별용.
    /// TODO: 서버가 userId를 주기 시작하면 닉네임 비교를 id 비교로 바꾼다(동명이인 오판 방지).
    public func isMine(currentUserNickname: String) -> Bool {
        !authorName.isEmpty && authorName == currentUserNickname
    }
}
