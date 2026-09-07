import ChatDomain
import Foundation
import PhotoDomain

/// 데모가 쓰는 고정 데이터.
enum DemoFixture {

    static let roomID: Int64 = -1
    static let roomTitle = "해피하우스 강릉 여행"
    /// 화면을 보는 사람 = 메시지를 보내는 사람(내 메시지 판별 기준).
    static let currentUserNickname = "아이스크림연준"

    static func messages() -> [ChatMessage] {
        [
            message(offset: -3600 * 3, kind: .photo, content: "", author: "그린그린엄성현",
                    photo: "https://picsum.photos/seed/challa-chat-1/300/400"),
            message(offset: -3600 * 2 - 1800, kind: .reaction(.heart), content: "heart", author: "아이스크림연준",
                    photo: "https://picsum.photos/seed/challa-chat-1/300/400"),
            message(offset: -3600 * 2, kind: .text, content: "사진 진짜 잘 나왔다", author: "그린그린엄성현"),
            message(offset: -3600, kind: .text, content: "그러게 필름 감성 미쳤어", author: currentUserNickname),
            message(offset: -600, kind: .text, content: "다음에 또 가자!", author: "그린그린엄성현"),
            message(offset: -60, kind: .text, content: "그냥 메시지를 보내면 이렇게", author: currentUserNickname)
        ]
    }

    private static func message(
        offset: TimeInterval,
        kind: ChatMessage.Kind,
        content: String,
        author: String,
        photo: String? = nil
    ) -> ChatMessage {
        ChatMessage(
            id: UUID(),
            kind: kind,
            content: content,
            photoImageURL: photo.flatMap(URL.init(string:)),
            authorName: author,
            authorImageURL: URL(string: "https://picsum.photos/seed/challa-\(author.hashValue)/80/80"),
            createdAt: Date(timeIntervalSinceNow: offset)
        )
    }
}
