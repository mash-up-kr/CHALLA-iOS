import ChatDomain
import Foundation
import PhotoDomain

extension ChatMessageDTO {

    /// DTO를 도메인 `ChatMessage`로 변환한다. 아이템 종류는 `type`과 `photoImageUrl`로 정한다:
    /// - `EMOJI` → 사진에 달린 이모지 리액션(`content`가 `ReactionKind`)
    /// - `DEFAULT` + 사진 → 사진 메시지(+content 텍스트)
    /// - `DEFAULT` + 사진 없음 → 텍스트 메시지
    /// 서버가 메시지 id를 주지 않아 호출부가 만든 `id`를 받는다. 보낸 사람 이름이 없거나 알 수 없는 이모지는 버린다.
    func toDomain(id: UUID) -> ChatMessage? {
        guard let userName, !userName.isEmpty else { return nil }
        let photoURL = photoImageUrl.flatMap(URL.init(string:))
        let text = content ?? ""

        let kind: ChatMessage.Kind
        if type == "EMOJI" {
            guard let reaction = ReactionKind(rawValue: text) else { return nil }
            kind = .reaction(reaction)
        } else if photoURL != nil {
            kind = .photo
        } else {
            kind = .text
        }

        return ChatMessage(
            id: id,
            kind: kind,
            content: text,
            photoImageURL: photoURL,
            authorName: userName,
            authorImageURL: userProfileImageUrl.flatMap(URL.init(string:)),
            // 파싱 실패 시 맨 앞으로 밀어 목록 순서를 흐트러뜨리지 않는다.
            createdAt: createdAt.flatMap(ServerDate.parse) ?? .distantPast
        )
    }
}

/// 서버 날짜 문자열을 `Date`로 바꾼다.
/// 백엔드 확정(2026-08-13): 타임존 표기 없이 UTC 기준 — 예: "2026-08-03T13:38:42.959736".
/// `PhotoData`·`RoomData`의 같은 이름 타입을 복사한 것 — 공용화(CHALLANetwork로 이동)는 #51 이후 정리한다.
enum ServerDate {

    private static let formats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS", // 마이크로초
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss" //         소수점 초가 0이면 생략될 수 있다
    ]

    private static let formatters: [DateFormatter] = formats.map { format in
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }

    static func parse(_ string: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
}
