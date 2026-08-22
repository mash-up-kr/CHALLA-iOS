import Foundation

/// `GET /api/v1/photos/{photoId}` 응답 껍데기 `{ photo: { id, chats } }`.
struct GetPhotoDetailEnvelopeDTO: Decodable, Sendable {

    let photo: PhotoDetailDTO
}

/// 사진 상세 — 리액션·코멘트가 `chats`로 온다. 목록 응답엔 없는 값이라 상세를 따로 조회한다.
struct PhotoDetailDTO: Decodable, Sendable {

    let id: Int64
    let chats: [ChatDTO]
}

/// 채팅 한 줄. 리액션은 `type == "EMOJI"` 채팅이고 `content`가 이모지 의미(ReactionKind.rawValue)다.
struct ChatDTO: Decodable, Sendable {

    let id: Int64?
    let type: String
    let content: String
    let userId: Int64
    /// 서버가 타임존 없이 UTC로 주는 문자열. 정렬(먼저 남긴 순)에 쓴다.
    let createdAt: String?
}
