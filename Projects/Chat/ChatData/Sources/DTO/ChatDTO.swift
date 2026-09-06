import Foundation

/// 방 메시지와 사진 메시지의 공통 요청 본문.
struct SendChatRequestDTO: Encodable, Sendable {

    let chat: Payload

    /// API 명세에 따라 사진이 없으면 `photoId`를 0으로 전송한다.
    /// TODO: 백엔드 확인 — 방 단위 메시지의 photoId 처리(0/생략) 확정 시 교체.
    init(roomID: Int64, photoID: Int64?, content: String) {
        let type: ChatMessageType = photoID == nil ? .text : .comment
        chat = Payload(roomId: roomID, photoId: photoID ?? 0, type: type.rawValue, content: content)
    }

    struct Payload: Encodable, Sendable {
        let roomId: Int64
        let photoId: Int64
        let type: String
        let content: String
    }
}

/// 채팅 한 건. `GET /chats/{roomId}`의 목록 항목과 `POST /chats`의 응답에 공통으로 쓰인다.
/// 서버가 메시지 id를 주지 않아 매핑에서 UUID를 생성한다.
struct ChatMessageDTO: Decodable, Sendable {
    let type: String?
    let content: String?
    let photoImageUrl: String?
    let createdAt: String?
    let userName: String?
    let userProfileImageUrl: String?

    /// 알 수 없는 종류가 와도 디코딩이 깨지지 않게 String으로 받고, 여기서 enum으로 해석한다.
    var messageType: ChatMessageType? {
        type.flatMap(ChatMessageType.init(rawValue:))
    }
}

/// `GET /api/v1/chats/{roomId}` 응답 페이로드.
struct ListChatsResponseDTO: Decodable, Sendable {
    let chats: [ChatMessageDTO]
}

/// `POST /api/v1/chats` 응답 페이로드.
///
/// 본문(생성된 chat)은 읽지 않는다 — 서버가 안정적으로 주지 않아 성공 여부만 확인한다.
/// 어떤 data 형태(객체/null)가 와도 디코딩이 깨지지 않도록 비워 둔다.
struct SendChatResponseDTO: Decodable, Sendable {}
