import Foundation

/// 서버 chat-controller가 쓰는 채팅 종류. 리액션은 `.emoji` 채팅이다.
/// 문자열 리터럴 비교를 없애려 enum으로 둔다(모듈별 서버 계약 복사본 — BaseResponseDTO·ServerDate와 같은 이유).
enum ChatMessageType: String, Sendable {
    case text = "DEFAULT"
    case emoji = "EMOJI"
    case comment = "COMMENT"
}
