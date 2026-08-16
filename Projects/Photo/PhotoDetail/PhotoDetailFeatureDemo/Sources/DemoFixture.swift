import Foundation
import PhotoDomain

/// 데모가 쓰는 고정 데이터. 시안에 적힌 값을 그대로 쓴다.
enum DemoFixture {

    static let roomID = "room-1"
    static let roomTitle = "해피하우스 강릉 여행"
    /// 화면을 보는 사람 = 리액션을 남기는 사람.
    static let currentUserID = "user-me"

    private static let author = PhotoAuthor(
        id: "user-tomato",
        nickname: "나는야멋쟁이토마토",
        avatarURL: URL(string: "https://picsum.photos/seed/challa-avatar/80/80")
    )

    /// 사진 5장. 첫 장에는 남이 남긴 리액션 하나가 붙어 있다 (시안의 스티커 상태).
    static func photos() -> [Photo] {
        (1 ... 5).compactMap { index in
            // 저장소에 샘플 이미지를 커밋하지 않고 실행 시점에 받아 쓴다 (검수앱 갤러리와 같은 방식).
            guard let imageURL = URL(string: "https://picsum.photos/seed/challa-\(index)/600/800") else {
                return nil
            }
            return Photo(
                id: "photo-\(index)",
                imageURL: imageURL,
                author: author,
                capturedAt: capturedAt,
                reactions: index == 1 ? [clapReaction] : []
            )
        }
    }

    /// 시안 표기 "2026. 7.16. 14:34".
    private static let capturedAt: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 16
        components.hour = 14
        components.minute = 34
        return Calendar(identifier: .gregorian).date(from: components) ?? Date(timeIntervalSince1970: 0)
    }()

    private static let clapReaction = PhotoReaction(kind: .clap, userID: "user-tomato")
}
