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

/// 리액션 생성 응답. 삭제에 필요한 `chatId`만 파싱한다.
/// 성공 응답에도 값이 누락될 수 있어 옵셔널로 선언한다.
struct CreateReactionResponseDTO: Decodable, Sendable {

    let chat: Payload?

    struct Payload: Decodable, Sendable {
        let chatId: Int64?
    }
}

/// 리액션 삭제 응답. 본문은 사용하지 않고 성공 여부만 확인한다.
struct DeleteReactionResponseDTO: Decodable, Sendable {}
