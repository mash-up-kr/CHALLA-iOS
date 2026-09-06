import Foundation
import PhotoDomain

/// 리액션 반영 결과를 들고 있는 메모리 저장소.
actor DemoPhotoStore {

    private var photos: [Photo]
    /// 서버 응답을 대신할 채팅 ID.
    private var nextChatID: Int64 = 1

    init(photos: [Photo]) {
        self.photos = photos
    }

    func all() -> [Photo] {
        photos
    }

    func photo(id: String) -> Photo? {
        photos.first { $0.id == id }
    }

    /// 리액션을 저장하고 삭제에 사용할 채팅 ID를 반환한다.
    func addReaction(photoID: String, kind: ReactionKind, userID: String) -> (photo: Photo, chatID: Int64)? {
        guard let index = photos.firstIndex(where: { $0.id == photoID }) else { return nil }
        let chatID = nextChatID
        nextChatID += 1
        photos[index] = photos[index].addingReaction(
            PhotoReaction(chatID: chatID, kind: kind, userID: userID)
        )
        return (photos[index], chatID)
    }

    func removeReaction(chatID: Int64) {
        for (index, photo) in photos.enumerated() {
            guard photo.reactions.contains(where: { $0.chatID == chatID }) else { continue }
            photos[index] = photo.removingReaction(id: PhotoReaction.id(forChatID: chatID))
            return
        }
    }
}
