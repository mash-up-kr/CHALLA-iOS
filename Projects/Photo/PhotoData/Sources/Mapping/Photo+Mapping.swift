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

    /// 상세의 `chats`(EMOJI)에서 두 가지를 함께 뽑는다:
    /// - `stickers`: **유저당 첫 이모지 하나** (처음 남긴 순서대로) — 사진 위 스티커용 (정책 #71)
    /// - `kindsByUser`: 유저별로 남긴 종류 **전부** — 리액션 바 칩의 띠용 (재진입 시 복원)
    /// 이모지가 아닌 채팅(DEFAULT·COMMENT)과 알 수 없는 종류는 버린다.
    func reactionData() -> (stickers: [PhotoReaction], kindsByUser: [String: Set<ReactionKind>]) {
        let emojiChats = chats
            .filter { $0.type == "EMOJI" }
            // 먼저 남긴 순으로 정렬 — 날짜가 없으면 뒤로 민다.
            .sorted { ($0.createdAt.flatMap(ServerDate.parse) ?? .distantFuture)
                < ($1.createdAt.flatMap(ServerDate.parse) ?? .distantFuture)
            }

        var kindsByUser: [String: Set<ReactionKind>] = [:]
        var seenUsers = Set<Int64>()
        var stickers: [PhotoReaction] = []
        for chat in emojiChats {
            guard let kind = ReactionKind(rawValue: chat.content) else { continue }
            let userID = String(chat.userId)
            kindsByUser[userID, default: []].insert(kind)
            if seenUsers.insert(chat.userId).inserted {
                stickers.append(PhotoReaction(kind: kind, userID: userID))
            }
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
