import Foundation

/// `POST /api/v1/chats/reaction` 요청 본문.
///
/// 서버는 리액션을 별도 모델이 아니라 `type = "EMOJI"` 채팅으로 다룬다 (chat-controller).
/// `content`에는 `ReactionKind.rawValue`를 그대로 싣는다 (자유 문자열).
struct CreateReactionRequestDTO: Encodable, Sendable {

    let chat: Payload

    init(roomID: Int64, photoID: Int64, content: String) {
        chat = Payload(roomId: roomID, photoId: photoID, type: ChatMessageType.emoji.rawValue, content: content)
    }

    struct Payload: Encodable, Sendable {
        let roomId: Int64
        let photoId: Int64
        let type: String
        let content: String
    }
}

/// `POST /api/v1/chats/reaction` 응답 페이로드.
///
/// 생성된 채팅만 돌려주고 갱신된 사진·리액션 목록은 주지 않는다 — 성공 여부 확인에만 쓴다.
/// 필드는 읽지 않으므로 비워 둔다 (`BaseResponseDTO.unwrap()`이 data 존재만 검증).
struct CreateReactionResponseDTO: Decodable, Sendable {}
