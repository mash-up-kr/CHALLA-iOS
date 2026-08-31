import Foundation
import PhotoDomain

/// 리액션 반영 결과를 들고 있는 메모리 저장소.
actor DemoPhotoStore {

    private var photos: [Photo]

    init(photos: [Photo]) {
        self.photos = photos
    }

    func all() -> [Photo] {
        photos
    }

    func photo(id: String) -> Photo? {
        photos.first { $0.id == id }
    }

    /// 첫 이모지면 스티커를 붙인다(정책 #71 — 유저당 첫 개만 스티커). 이후 이모지는 화면 변화 없음.
    func addReaction(photoID: String, kind: ReactionKind, userID: String) -> Photo? {
        guard let index = photos.firstIndex(where: { $0.id == photoID }) else { return nil }
        photos[index] = photos[index].addingReaction(kind, by: userID)
        return photos[index]
    }
}
