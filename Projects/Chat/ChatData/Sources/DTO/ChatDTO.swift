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

/// 채팅 한 건. `GET /chats/{roomId}`의 목록 항목과 소켓 이벤트에 공통으로 쓰인다.
///
/// `chatId`·`userId`는 API 명세상 필수지만 optional로 받는다 — 명세와 실제 응답이 어긋난 이력이 있다
/// (이 DTO 자체가 그 두 필드를 아예 읽지 않고 있었다). 값이 없는 항목은 매핑에서 버린다.
struct ChatMessageDTO: Decodable, Sendable {
    let chatId: Int64?
    let userId: Int64?
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
/// `chatId`만 읽는다. 화면이 낙관적 메시지를 이 id로 확정하면, 소켓으로 되돌아온 같은 메시지가
/// 목록에 두 번 뜨지 않는다. 서버가 본문을 안 주던 이력이 있어 optional이고, 없으면 로컬 id로 남는다.
struct SendChatResponseDTO: Decodable, Sendable {
    let chatId: Int64?
}

/// 소켓 이벤트 본문(`{ "chat": { ... } }`). REST 응답과 같은 봉투 안에 담겨 온다.
struct ChatEventPayloadDTO: Decodable, Sendable {
    let chat: ChatMessageDTO
}
