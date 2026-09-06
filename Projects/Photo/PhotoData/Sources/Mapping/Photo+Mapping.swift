import Foundation
import PhotoDomain

extension ListPhotosResponseDTO {

    /// 목록 응답 한 장을 도메인 `Photo`로 변환한다. 리액션은 상세(`chats`)에서 온 값을 받아 붙인다.
    ///
    /// 표시할 이미지 URL이 없거나(인화 전) 날짜 파싱에 실패하면 `nil`을 돌려주고 호출부가 그 장을 건너뛴다 —
    /// 사진 한 장 때문에 목록 전체가 실패하지 않게 한다.
    func toDomain(
        reactions: [PhotoReaction] = [],
        reactedKindsByUser: [String: Set<ReactionKind>] = [:]
    ) -> Photo? {
        guard let imageUrl, let imageURL = URL(string: imageUrl),
              let capturedAt = ServerDate.parse(createdAt)
        else {
            return nil
        }

        return Photo(
            id: String(id),
            imageURL: imageURL,
            // 서버 목록·상세 어디에도 작성자 userId가 없다 — 표시에 쓰는 닉네임·이미지만 채운다.
            author: PhotoAuthor(
                id: "",
                nickname: userNickname,
                avatarURL: userProfileImageUrl.flatMap(URL.init(string:))
            ),
            capturedAt: capturedAt,
            reactions: reactions,
            reactedKindsByUser: reactedKindsByUser
        )
    }
}

extension PhotoDetailDTO {

    /// EMOJI 채팅을 등록 순서의 스티커와 사용자별 이모지 종류로 변환한다.
    /// 채팅 ID가 없으면 표시용 ID만 생성하며, 삭제는 지원하지 않는다.
    func reactionData() -> (stickers: [PhotoReaction], kindsByUser: [String: Set<ReactionKind>]) {
        let emojiChats = chats
            .filter { $0.messageType == .emoji }
            // 먼저 남긴 순으로 정렬 — 날짜가 없으면 뒤로 민다.
            .sorted { ($0.createdAt.flatMap(ServerDate.parse) ?? .distantFuture)
                < ($1.createdAt.flatMap(ServerDate.parse) ?? .distantFuture)
            }

        var kindsByUser: [String: Set<ReactionKind>] = [:]
        var stickers: [PhotoReaction] = []
        // 같은 유저가 같은 종류를 같은 시각에 두 번 남긴 경우를 갈라 준다.
        var fallbackCounts: [String: Int] = [:]

        for chat in emojiChats {
            guard let kind = ReactionKind(rawValue: chat.content) else { continue }
            let userID = String(chat.userId)
            kindsByUser[userID, default: []].insert(kind)

            if let chatID = chat.id {
                stickers.append(PhotoReaction(chatID: chatID, kind: kind, userID: userID))
                continue
            }

            // 채팅 id가 없을 때의 대체 신원.
            // 순번(0, 1, 2…)을 쓰면 앞의 채팅이 하나 지워질 때 남은 스티커의 id가 전부 밀려
            // 화면 위 자리가 통째로 바뀐다. 내용으로 만든 키는 목록이 바뀌어도 그대로다.
            let base = "chat-\(userID)-\(kind.rawValue)-\(chat.createdAt ?? "")"
            let seen = fallbackCounts[base, default: 0]
            fallbackCounts[base] = seen + 1
            stickers.append(PhotoReaction(id: "\(base)-\(seen)", kind: kind, userID: userID))
        }
        return (stickers, kindsByUser)
    }
}

/// 서버 날짜 문자열을 `Date`로 바꾼다.
/// 백엔드 확정(2026-08-13): 타임존 표기 없이 UTC 기준 — 예: "2026-08-03T13:38:42.959736".
/// `RoomData`의 같은 이름 타입을 복사한 것 — 공용화(CHALLANetwork로 이동)는 #51 이후 정리한다.
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
